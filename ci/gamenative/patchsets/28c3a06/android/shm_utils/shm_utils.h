/*
 * Shared memory utility functions
 *
 * Copyright (C) 2018 Zebediah Figura
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110-1301, USA
 */

#ifndef __WINE_SERVER_SHM_UTILS_H
#define __WINE_SERVER_SHM_UTILS_H

#ifdef __ANDROID__

#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

static inline int shm_open(const char *name, int oflag, mode_t mode)
{
    const char *tmpdir = getenv("TMPDIR");
    char *fname = NULL;

    if (!tmpdir) tmpdir = "/tmp";
    if (asprintf(&fname, "%s/%s", tmpdir, name) < 0) return -1;

    {
        int fd = open(fname, oflag, mode);
        free(fname);
        return fd;
    }
}

static inline int shm_unlink(const char *name)
{
    const char *tmpdir = getenv("TMPDIR");
    char *fname = NULL;

    if (!tmpdir) tmpdir = "/tmp";
    if (asprintf(&fname, "%s/%s", tmpdir, name) < 0) return -1;

    {
        int rc = unlink(fname);
        free(fname);
        return rc;
    }
}

#endif /* __ANDROID__ */

#endif /* __WINE_SERVER_SHM_UTILS_H */
