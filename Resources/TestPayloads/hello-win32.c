#include <stdio.h>
#include <windows.h>

int main(void) {
    printf("Hello from Windows!\n");
    printf("CellarKit Stage-2 test payload\n");
    printf("Process ID: %lu\n", (unsigned long)GetCurrentProcessId());
    printf("Wine/NTDLL loaded OK\n");
    fflush(stdout);
    return 0;
}
