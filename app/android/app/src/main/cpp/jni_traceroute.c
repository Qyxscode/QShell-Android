#include <jni.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <errno.h>
#include <sys/socket.h>
#include <sys/time.h>
#include <netinet/in.h>
#include <netinet/ip.h>
#include <netinet/ip_icmp.h>
#include <arpa/inet.h>
#include <netdb.h>
#include <time.h>
#include <linux/errqueue.h>
#include <sys/uio.h>

/*
 * 非特权 ICMP traceroute。
 *
 * 关键点：Linux 把 ICMP Time Exceeded 放进 ping socket 的「错误队列」，
 * 必须用 recvmsg(MSG_ERRQUEUE) + IP_RECVERR 才能拿到，并且报文控制消息里
 * 带 offender 地址（即回了 Time Exceeded 的路由器）。纯 Java 层拿不到。
 */

static unsigned short icmp_checksum(void *data, int len) {
    unsigned short *buf = (unsigned short *) data;
    unsigned int sum = 0;
    unsigned short result;
    for (sum = 0; len > 1; len -= 2) sum += *buf++;
    if (len == 1) sum += *(unsigned char *) buf;
    sum = (sum >> 16) + (sum & 0xFFFF);
    sum += (sum >> 16);
    result = (unsigned short) ~sum;
    return result;
}

static long long now_us(void) {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (long long) ts.tv_sec * 1000000LL + ts.tv_nsec / 1000;
}

JNIEXPORT jobjectArray JNICALL
Java_com_a6704_qshell_NativeTraceroute_traceNative(JNIEnv *env, jclass clazz,
                                                   jstring jhost, jint maxHops, jint timeoutMs) {
    const char *host = (*env)->GetStringUTFChars(env, jhost, NULL);
    if (host == NULL) return NULL;

    struct sockaddr_in dest;
    memset(&dest, 0, sizeof(dest));
    dest.sin_family = AF_INET;

    if (inet_pton(AF_INET, host, &dest.sin_addr) != 1) {
        struct addrinfo hints;
        struct addrinfo *res = NULL;
        memset(&hints, 0, sizeof(hints));
        hints.ai_family = AF_INET;
        hints.ai_socktype = SOCK_DGRAM;
        if (getaddrinfo(host, NULL, &hints, &res) != 0 || res == NULL) {
            (*env)->ReleaseStringUTFChars(env, jhost, host);
            return NULL;
        }
        dest.sin_addr = ((struct sockaddr_in *) res->ai_addr)->sin_addr;
        freeaddrinfo(res);
    }
    (*env)->ReleaseStringUTFChars(env, jhost, host);

    jclass string_class = (*env)->FindClass(env, "java/lang/String");
    if (string_class == NULL) return NULL;
    jobjectArray result = (*env)->NewObjectArray(env, maxHops, string_class, NULL);
    if (result == NULL) return NULL;

    int fd = socket(AF_INET, SOCK_DGRAM, IPPROTO_ICMP);
    if (fd < 0) return NULL;

    struct timeval tv;
    tv.tv_sec = timeoutMs / 1000;
    tv.tv_usec = (timeoutMs % 1000) * 1000;
    setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &tv, sizeof(tv));

    int on = 1;
    setsockopt(fd, IPPROTO_IP, IP_RECVERR, &on, sizeof(on));

    int count = 0;
    char line[256];
    static const int payload_size = 16;

    for (int ttl = 1; ttl <= maxHops; ttl++) {
        if (setsockopt(fd, IPPROTO_IP, IP_TTL, &ttl, sizeof(ttl)) != 0) {
            break;
        }

        unsigned char packet[sizeof(struct icmphdr) + 16];
        memset(packet, 0, sizeof(packet));
        struct icmphdr *icmp = (struct icmphdr *) packet;
        icmp->type = ICMP_ECHO;
        icmp->code = 0;
        icmp->un.echo.id = htons((unsigned short) (getpid() & 0xFFFF));
        icmp->un.echo.sequence = htons((unsigned short) ttl);
        for (int i = 0; i < payload_size; i++) {
            packet[sizeof(struct icmphdr) + i] = (unsigned char) ('a' + (i % 26));
        }
        icmp->checksum = 0;
        icmp->checksum = icmp_checksum(packet, sizeof(packet));

        long long start = now_us();
        if (sendto(fd, packet, sizeof(packet), 0, (struct sockaddr *) &dest, sizeof(dest)) < 0) {
            break;
        }

        char hop_ip[INET_ADDRSTRLEN] = "";
        double rtt = -1.0;
        int reached = 0;
        int got = 0;

        // 轮询：错误队列（Time Exceeded）和数据队列（Echo Reply）都非阻塞读，
        // 避免每跳都等满超时。
        long long deadline = now_us() + (long long) timeoutMs * 1000LL;
        while (now_us() < deadline && !got) {
            struct msghdr msg;
            struct iovec iov;
            char buf[512];
            char control[512];
            struct sockaddr_in from;
            memset(&msg, 0, sizeof(msg));
            memset(&from, 0, sizeof(from));
            iov.iov_base = buf;
            iov.iov_len = sizeof(buf);
            msg.msg_name = &from;
            msg.msg_namelen = sizeof(from);
            msg.msg_iov = &iov;
            msg.msg_iovlen = 1;
            msg.msg_control = control;
            msg.msg_controllen = sizeof(control);

            ssize_t n = recvmsg(fd, &msg, MSG_ERRQUEUE | MSG_DONTWAIT);
            if (n >= 0) {
                struct cmsghdr *cmsg;
                for (cmsg = CMSG_FIRSTHDR(&msg); cmsg != NULL; cmsg = CMSG_NXTHDR(&msg, cmsg)) {
                    if (cmsg->cmsg_level == IPPROTO_IP && cmsg->cmsg_type == IP_RECVERR) {
                        struct sock_extended_err *ee =
                                (struct sock_extended_err *) CMSG_DATA(cmsg);
                        if (ee->ee_origin == SO_EE_ORIGIN_ICMP) {
                            if (ee->ee_type == ICMP_TIME_EXCEEDED) {
                                struct sockaddr *offender = SO_EE_OFFENDER(ee);
                                if (offender != NULL && offender->sa_family == AF_INET) {
                                    inet_ntop(AF_INET,
                                              &((struct sockaddr_in *) offender)->sin_addr,
                                              hop_ip, sizeof(hop_ip));
                                }
                                if (hop_ip[0] == '\0' && from.sin_family == AF_INET) {
                                    inet_ntop(AF_INET, &from.sin_addr, hop_ip, sizeof(hop_ip));
                                }
                                rtt = (double) (now_us() - start) / 1000.0;
                                got = 1;
                                break;
                            }
                            if (ee->ee_type == ICMP_DEST_UNREACH) {
                                reached = 1;
                                if (from.sin_family == AF_INET) {
                                    inet_ntop(AF_INET, &from.sin_addr, hop_ip, sizeof(hop_ip));
                                } else {
                                    inet_ntop(AF_INET, &dest.sin_addr, hop_ip, sizeof(hop_ip));
                                }
                                rtt = (double) (now_us() - start) / 1000.0;
                                got = 1;
                                break;
                            }
                        }
                    }
                }
                if (got) break;
                continue;
            }

            // 正常数据队列（Echo Reply）
            struct sockaddr_in src;
            memset(&src, 0, sizeof(src));
            socklen_t src_len = sizeof(src);
            ssize_t m = recvfrom(fd, buf, sizeof(buf), MSG_DONTWAIT,
                                 (struct sockaddr *) &src, &src_len);
            if (m >= (ssize_t) sizeof(struct icmphdr)) {
                struct icmphdr *reply = (struct icmphdr *) buf;
                if (reply->type == ICMP_ECHOREPLY &&
                    ntohs(reply->un.echo.sequence) == (unsigned short) ttl) {
                    reached = 1;
                    inet_ntop(AF_INET, &src.sin_addr, hop_ip, sizeof(hop_ip));
                    rtt = (double) (now_us() - start) / 1000.0;
                    got = 1;
                    break;
                }
            }
            usleep(10000);
        }

        if (hop_ip[0] == '\0') {
            snprintf(line, sizeof(line), "%d||-1|0", ttl);
        } else {
            snprintf(line, sizeof(line), "%d|%s|%.1f|%d", ttl, hop_ip, rtt, reached);
        }
        jstring item = (*env)->NewStringUTF(env, line);
        if (item != NULL) {
            (*env)->SetObjectArrayElement(env, result, count++, item);
            (*env)->DeleteLocalRef(env, item);
        }
        if (reached) break;
    }

    close(fd);

    jobjectArray out = (*env)->NewObjectArray(env, count, string_class, NULL);
    for (int i = 0; i < count; i++) {
        jobject element = (*env)->GetObjectArrayElement(env, result, i);
        (*env)->SetObjectArrayElement(env, out, i, element);
        (*env)->DeleteLocalRef(env, element);
    }
    return out;
}

/*
 * 流式版本：每测完一跳就通过 callback.onHop(ttl, ip, rtt, reached) 回调回去，
 * 让 Dart 侧能一条一条地显示，而不是等全部跑完。
 */
JNIEXPORT void JNICALL
Java_com_a6704_qshell_NativeTraceroute_traceStream(JNIEnv *env, jclass clazz,
                                                   jstring jhost, jint maxHops,
                                                   jint timeoutMs, jobject callback) {
    jclass cb_class = (*env)->GetObjectClass(env, callback);
    if (cb_class == NULL) return;
    jmethodID on_hop = (*env)->GetMethodID(
            env, cb_class, "onHop", "(ILjava/lang/String;DZ)V");
    if (on_hop == NULL) return;

    const char *host = (*env)->GetStringUTFChars(env, jhost, NULL);
    if (host == NULL) return;

    struct sockaddr_in dest;
    memset(&dest, 0, sizeof(dest));
    dest.sin_family = AF_INET;

    if (inet_pton(AF_INET, host, &dest.sin_addr) != 1) {
        struct addrinfo hints;
        struct addrinfo *res = NULL;
        memset(&hints, 0, sizeof(hints));
        hints.ai_family = AF_INET;
        hints.ai_socktype = SOCK_DGRAM;
        if (getaddrinfo(host, NULL, &hints, &res) != 0 || res == NULL) {
            (*env)->ReleaseStringUTFChars(env, jhost, host);
            return;
        }
        dest.sin_addr = ((struct sockaddr_in *) res->ai_addr)->sin_addr;
        freeaddrinfo(res);
    }
    (*env)->ReleaseStringUTFChars(env, jhost, host);

    int fd = socket(AF_INET, SOCK_DGRAM, IPPROTO_ICMP);
    if (fd < 0) return;

    struct timeval tv;
    tv.tv_sec = timeoutMs / 1000;
    tv.tv_usec = (timeoutMs % 1000) * 1000;
    setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &tv, sizeof(tv));

    int on = 1;
    setsockopt(fd, IPPROTO_IP, IP_RECVERR, &on, sizeof(on));

    static const int payload_size = 16;

    for (int ttl = 1; ttl <= maxHops; ttl++) {
        if (setsockopt(fd, IPPROTO_IP, IP_TTL, &ttl, sizeof(ttl)) != 0) {
            break;
        }

        unsigned char packet[sizeof(struct icmphdr) + 16];
        memset(packet, 0, sizeof(packet));
        struct icmphdr *icmp = (struct icmphdr *) packet;
        icmp->type = ICMP_ECHO;
        icmp->code = 0;
        icmp->un.echo.id = htons((unsigned short) (getpid() & 0xFFFF));
        icmp->un.echo.sequence = htons((unsigned short) ttl);
        for (int i = 0; i < payload_size; i++) {
            packet[sizeof(struct icmphdr) + i] = (unsigned char) ('a' + (i % 26));
        }
        icmp->checksum = 0;
        icmp->checksum = icmp_checksum(packet, sizeof(packet));

        long long start = now_us();
        if (sendto(fd, packet, sizeof(packet), 0,
                   (struct sockaddr *) &dest, sizeof(dest)) < 0) {
            break;
        }

        char hop_ip[INET_ADDRSTRLEN] = "";
        double rtt = -1.0;
        int reached = 0;
        int got = 0;

        long long deadline = now_us() + (long long) timeoutMs * 1000LL;
        while (now_us() < deadline && !got) {
            struct msghdr msg;
            struct iovec iov;
            char buf[512];
            char control[512];
            struct sockaddr_in from;
            memset(&msg, 0, sizeof(msg));
            memset(&from, 0, sizeof(from));
            iov.iov_base = buf;
            iov.iov_len = sizeof(buf);
            msg.msg_name = &from;
            msg.msg_namelen = sizeof(from);
            msg.msg_iov = &iov;
            msg.msg_iovlen = 1;
            msg.msg_control = control;
            msg.msg_controllen = sizeof(control);

            ssize_t n = recvmsg(fd, &msg, MSG_ERRQUEUE | MSG_DONTWAIT);
            if (n >= 0) {
                struct cmsghdr *cmsg;
                for (cmsg = CMSG_FIRSTHDR(&msg); cmsg != NULL;
                     cmsg = CMSG_NXTHDR(&msg, cmsg)) {
                    if (cmsg->cmsg_level == IPPROTO_IP &&
                        cmsg->cmsg_type == IP_RECVERR) {
                        struct sock_extended_err *ee =
                                (struct sock_extended_err *) CMSG_DATA(cmsg);
                        if (ee->ee_origin == SO_EE_ORIGIN_ICMP) {
                            if (ee->ee_type == ICMP_TIME_EXCEEDED) {
                                struct sockaddr *offender = SO_EE_OFFENDER(ee);
                                if (offender != NULL &&
                                    offender->sa_family == AF_INET) {
                                    inet_ntop(AF_INET,
                                              &((struct sockaddr_in *) offender)->sin_addr,
                                              hop_ip, sizeof(hop_ip));
                                }
                                if (hop_ip[0] == '\0' && from.sin_family == AF_INET) {
                                    inet_ntop(AF_INET, &from.sin_addr,
                                              hop_ip, sizeof(hop_ip));
                                }
                                rtt = (double) (now_us() - start) / 1000.0;
                                got = 1;
                                break;
                            }
                            if (ee->ee_type == ICMP_DEST_UNREACH) {
                                reached = 1;
                                if (from.sin_family == AF_INET) {
                                    inet_ntop(AF_INET, &from.sin_addr,
                                              hop_ip, sizeof(hop_ip));
                                } else {
                                    inet_ntop(AF_INET, &dest.sin_addr,
                                              hop_ip, sizeof(hop_ip));
                                }
                                rtt = (double) (now_us() - start) / 1000.0;
                                got = 1;
                                break;
                            }
                        }
                    }
                }
                if (got) break;
                continue;
            }

            struct sockaddr_in src;
            memset(&src, 0, sizeof(src));
            socklen_t src_len = sizeof(src);
            ssize_t m = recvfrom(fd, buf, sizeof(buf), MSG_DONTWAIT,
                                 (struct sockaddr *) &src, &src_len);
            if (m >= (ssize_t) sizeof(struct icmphdr)) {
                struct icmphdr *reply = (struct icmphdr *) buf;
                if (reply->type == ICMP_ECHOREPLY &&
                    ntohs(reply->un.echo.sequence) == (unsigned short) ttl) {
                    reached = 1;
                    inet_ntop(AF_INET, &src.sin_addr, hop_ip, sizeof(hop_ip));
                    rtt = (double) (now_us() - start) / 1000.0;
                    got = 1;
                    break;
                }
            }
            usleep(10000);
        }

        // 逐跳回调回 Java 层
        jstring ip_str = hop_ip[0] == '\0' ? NULL : (*env)->NewStringUTF(env, hop_ip);
        (*env)->CallVoidMethod(env, callback, on_hop,
                               (jint) ttl, ip_str, (jdouble) rtt, (jint) reached);
        if (ip_str != NULL) (*env)->DeleteLocalRef(env, ip_str);

        if ((*env)->ExceptionCheck(env)) break;
        if (reached) break;
    }

    close(fd);
}
