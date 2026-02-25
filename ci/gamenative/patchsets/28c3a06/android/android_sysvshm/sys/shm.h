#ifndef _SYS_SHM_H
#define _SYS_SHM_H 1

#include <stdint.h>
#include <sys/types.h>

#ifdef __cplusplus
extern "C" {
#endif

#define IPC_CREAT 01000
#define IPC_EXCL 02000
#define IPC_NOWAIT 04000

#define IPC_RMID 0
#define IPC_SET 1
#define IPC_STAT 2
#define IPC_INFO 3

#define IPC_PRIVATE ((key_t)0)

#define SHM_R 0400
#define SHM_W 0200

#define SHM_RDONLY 010000
#define SHM_RND 020000
#define SHM_REMAP 040000
#define SHM_EXEC 0100000

#define SHM_LOCK 11
#define SHM_UNLOCK 12

typedef unsigned long int shmatt_t;
typedef long int __long_time_t;

struct debian_ipc_perm
{
    key_t __key;
    __uid_t uid;
    __gid_t gid;
    __uid_t cuid;
    __gid_t cgid;
    unsigned short int mode;
    unsigned short int __pad1;
    unsigned short int __seq;
    unsigned short int __pad2;
    unsigned long int __unused1;
    unsigned long int __unused2;
};

struct shmid_ds
{
    struct debian_ipc_perm shm_perm;
    size_t shm_segsz;
    __long_time_t shm_atime;
    unsigned long int __unused1;
    __long_time_t shm_dtime;
    unsigned long int __unused2;
    __long_time_t shm_ctime;
    unsigned long int __unused3;
    __pid_t shm_cpid;
    __pid_t shm_lpid;
    shmatt_t shm_nattch;
    unsigned long int __unused4;
    unsigned long int __unused5;
};

extern int shmctl(int __shmid, int __cmd, struct shmid_ds *__buf);
extern int shmget(key_t __key, size_t __size, int __shmflg);
extern void *shmat(int __shmid, const void *__shmaddr, int __shmflg);
extern int shmdt(const void *__shmaddr);

#ifdef __cplusplus
}
#endif

#endif
