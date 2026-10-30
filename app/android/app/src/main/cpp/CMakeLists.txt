cmake_minimum_required(VERSION 3.22.1)
project(qshell_native C)

add_library(qshell_native SHARED jni_traceroute.c)

find_library(log-lib log)
target_link_libraries(qshell_native ${log-lib})
