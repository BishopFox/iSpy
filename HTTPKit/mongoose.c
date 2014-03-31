// Copyright (c) 2004-2013 Sergey Lyubka
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#ifdef __linux__
#define _XOPEN_SOURCE 600       // For flockfile() on Linux
#endif
//#define _LARGEFILE_SOURCE       // Enable 64-bit file offsets
#define __STDC_FORMAT_MACROS    // <inttypes.h> wants this for C++
#define __STDC_LIMIT_MACROS     // C++ wants that for INT64_MAX
//#define _GNU_SOURCE

#include <sys/types.h>
#include <sys/stat.h>
#include <errno.h>
#include <signal.h>
#include <fcntl.h>

#include <time.h>
#include <stdlib.h>
#include <stdarg.h>
#include <assert.h>
#include <string.h>
#include <ctype.h>
#include <limits.h>
#include <stddef.h>
#include <stdio.h>

#include <sys/wait.h>
#include <sys/socket.h>
#include <sys/poll.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <sys/time.h>
#include <stdint.h>
#include <inttypes.h>
#include <netdb.h>

#include <pwd.h>
#include <unistd.h>
#include <dirent.h>
#include <pthread.h>

#include <openssl/ssl.h>
#include <openssl/md5.h>
#include <openssl/sha.h>
#include <openssl/err.h>

#define closesocket(a) close(a)
#define mg_sleep(x) usleep((x) * 1000)
#define INVALID_SOCKET (-1)
#define INT64_FMT PRId64
typedef int SOCKET;

#include "mongoose.h"

#define PASSWORDS_FILE_NAME ".htpasswd"
#define MG_BUF_LEN 8192
#define MAX_REQUEST_SIZE 16384
#define ARRAY_SIZE(array) (sizeof(array) / sizeof(array[0]))

#ifdef DEBUG_TRACE
    #undef DEBUG_TRACE
    #define DEBUG_TRACE(x)
#else
    #ifdef DEBUG
        #define DEBUG_TRACE(x) do { \
            flockfile(stdout); \
            printf("*** %lu.%p.%s.%d: ", \
                   (unsigned long) time(NULL), (void *) pthread_self(), \
                   __func__, __LINE__); \
            printf x; \
            putchar('\n'); \
            fflush(stdout); \
            funlockfile(stdout); \
        } while(0)
    #else
        #define DEBUG_TRACE(x)
    #endif // DEBUG
#endif // DEBUG_TRACE

#define _DARWIN_UNLIMITED_SELECT

#define IP_ADDR_STR_LEN 50 // IPv6 hex string is 46 chars

#if !defined(MSG_NOSIGNAL)
    #define MSG_NOSIGNAL 0
#endif

#if !defined(SOMAXCONN)
    #define SOMAXCONN 256
#endif

#if !defined(PATH_MAX)
    #define PATH_MAX 4096
#endif

// Size of the accepted socket queue
#if !defined(MGSQLEN)
    #define MGSQLEN 128
#endif

static const char *http_500_error = "Internal Server Error";

static const char *month_names[] = {
    "Jan", "Feb", "Mar", "Apr", "May", "Jun",
    "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"
};

// Unified socket address. For IPv6 support, add IPv6 address structure
// in the union u.
union usa {
    struct sockaddr sa;
    struct sockaddr_in sin;
#if defined(USE_IPV6)
    struct sockaddr_in6 sin6;
#endif
};

// Describes a string (chunk of memory).
struct vec {
    const char *ptr;
    size_t len;
};

struct file {
    int is_directory;
    time_t modification_time;
    int64_t size;
    FILE *fp;
    const char *membuf; // Non-NULL if file data is in memory
    // set to 1 if the content is gzipped
    // in which case we need a content-encoding: gzip header
    int gzipped;
};
#define STRUCT_FILE_INITIALIZER {0, 0, 0, NULL, NULL, 0}

// Describes listening socket, or socket which was accept()-ed by the master
// thread and queued for future handling by the worker thread.
struct socket {
    SOCKET sock;          // Listening socket
    union usa lsa;        // Local socket address
    union usa rsa;        // Remote socket address
    unsigned is_ssl:1;    // Is port SSL-ed
    unsigned ssl_redir:1; // Is port supposed to redirect everything to SSL port
};

// NOTE(lsm): this enum shoulds be in sync with the config_options below.
enum {
    PUT_DELETE_PASSWORDS_FILE,
    PROTECT_URI, AUTHENTICATION_DOMAIN, THROTTLE,
    ACCESS_LOG_FILE, ENABLE_DIRECTORY_LISTING, ERROR_LOG_FILE,
    GLOBAL_PASSWORDS_FILE, INDEX_FILES, ENABLE_KEEP_ALIVE, ACCESS_CONTROL_LIST,
    EXTRA_MIME_TYPES, LISTENING_PORTS, DOCUMENT_ROOT, SSL_CERTIFICATE,
    NUM_THREADS, RUN_AS_USER, REWRITE, HIDE_FILES, REQUEST_TIMEOUT,
    NUM_OPTIONS
};

static const char *config_options[] = {
    "put_delete_auth_file", NULL,
    "protect_uri", NULL,
    "authentication_domain", "mydomain.com",
    "throttle", NULL,
    "access_log_file", NULL,
    "enable_directory_listing", "yes",
    "error_log_file", NULL,
    "global_auth_file", NULL,
    "index_files", "index.html,index.htm",
    "enable_keep_alive", "no",
    "access_control_list", NULL,
    "extra_mime_types", NULL,
    "listening_ports", "8080",
    "document_root",    NULL,
    "ssl_certificate", NULL,
    "num_threads", "50",
    "run_as_user", NULL,
    "url_rewrite_patterns", NULL,
    "hide_files_patterns", NULL,
    "request_timeout_ms", "120000",
    NULL
};

struct mg_context {
    volatile int stop_flag;           // Should we stop event loop
    SSL_CTX *ssl_ctx;                 // SSL context
    char *config[NUM_OPTIONS];        // Mongoose configuration parameters
    struct mg_callbacks callbacks;    // User-defined callback function
    void *user_data;                  // User-defined data

    struct socket *listening_sockets;
    int num_listening_sockets;

    volatile int num_threads;        // Number of threads
    pthread_mutex_t mutex;           // Protects (max|num)_threads
    pthread_cond_t  cond;            // Condvar for tracking workers terminations

    struct socket queue[MGSQLEN];    // Accepted sockets
    volatile int sq_head;            // Head of the socket queue
    volatile int sq_tail;            // Tail of the socket queue
    pthread_cond_t sq_full;          // Signaled when socket is produced
    pthread_cond_t sq_empty;         // Signaled when socket is consumed
};

struct mg_connection {
    struct mg_request_info request_info;
    struct mg_context *ctx;
    SSL *ssl;                     // SSL descriptor
    SSL_CTX *client_ssl_ctx;      // SSL context for client connections
    struct socket client;         // Connected client
    time_t birth_time;            // Time when request was received
    int64_t num_bytes_sent;       // Total bytes sent to client
    int64_t content_len;          // Content-Length header value
    int64_t consumed_content;     // How many bytes of content have been read
    char *buf;                    // Buffer for received data
    char *path_info;              // PATH_INFO part of the URL
    int must_close;               // 1 if connection must be closed
    int buf_size;                 // Buffer size
    int request_len;              // Size of the request + headers in a buffer
    int data_len;                 // Total size of data in a buffer
    int status_code;              // HTTP reply status code, e.g. 200
    int throttle;                 // Throttling, bytes/sec. <= 0 means no throttle
    time_t last_throttle_time;    // Last time throttled data was sent
    int64_t last_throttle_bytes;  // Bytes sent this second
};

// Directory entry
struct de {
    struct mg_connection *conn;
    char *file_name;
    struct file file;
};

const char **mg_get_valid_option_names(void) {
    return config_options;
}

static int is_file_in_memory(struct mg_connection *conn, const char *path,
                             struct file *filep) {
    return 0;
    
    size_t size = 0;
    if((filep->membuf = conn->ctx->callbacks.open_file == NULL ? NULL :
         conn->ctx->callbacks.open_file(conn, path, &size)) != NULL) {
        // NOTE: override filep->size only on success. Otherwise, it might break
        // constructs like if(!mg_stat() || !mg_fopen()) ...
        filep->size = size;
    }
    return filep->membuf != NULL;
}

static int is_file_opened(const struct file *filep) {
    return filep->membuf != NULL || filep->fp != NULL;
}

static int mg_fopen(struct mg_connection *conn, const char *path,
                    const char *mode, struct file *filep) {
    if(!is_file_in_memory(conn, path, filep)) {
        filep->fp = fopen(path, mode);
    }

    return is_file_opened(filep);
}

static void mg_fclose(struct file *filep) {
    if(filep != NULL && filep->fp != NULL) {
        fclose(filep->fp);
    }
}

static int get_option_index(const char *name) {
    int i;

    for(i = 0; config_options[i * 2] != NULL; i++) {
        if(strcmp(config_options[i * 2], name) == 0) {
            return i;
        }
    }
    return -1;
}

const char *mg_get_option(const struct mg_context *ctx, const char *name) {
    int i;
    if((i = get_option_index(name)) == -1) {
        return NULL;
    } else if(ctx->config[i] == NULL) {
        return "";
    } else {
        return ctx->config[i];
    }
}

static void sockaddr_to_string(char *buf, size_t len, const union usa *usa) {
    buf[0] = '\0';
#if defined(USE_IPV6)
    inet_ntop(usa->sa.sa_family, usa->sa.sa_family == AF_INET ?
                        (void *) &usa->sin.sin_addr :
                        (void *) &usa->sin6.sin6_addr, buf, len);
    inet_ntop(usa->sa.sa_family, (void *) &usa->sin.sin_addr, buf, len);
#endif
}

static void cry(struct mg_connection *conn, const char *fmt, ...) PRINTF_ARGS(2, 3);

// Print error message to the opened error log stream.
static void cry(struct mg_connection *conn, const char *fmt, ...) {
    char buf[MG_BUF_LEN], src_addr[IP_ADDR_STR_LEN];
    va_list ap;
    FILE *fp;
    time_t timestamp;

    va_start(ap, fmt);
    (void) vsnprintf(buf, sizeof(buf), fmt, ap);
    va_end(ap);

    // Do not lock when getting the callback value, here and below.
    // I suppose this is fine, since function cannot disappear in the
    // same way string option can.
    if(conn->ctx->callbacks.log_message == NULL ||
            conn->ctx->callbacks.log_message(conn, buf) == 0) {
        fp = conn->ctx == NULL || conn->ctx->config[ERROR_LOG_FILE] == NULL ? NULL :
            fopen(conn->ctx->config[ERROR_LOG_FILE], "a+");

        if(fp != NULL) {
            flockfile(fp);
            timestamp = time(NULL);

            sockaddr_to_string(src_addr, sizeof(src_addr), &conn->client.rsa);
            fprintf(fp, "[%010lu] [error] [client %s] ", (unsigned long) timestamp,
                            src_addr);

            if(conn->request_info.request_method != NULL) {
                fprintf(fp, "%s %s: ", conn->request_info.request_method,
                                conn->request_info.uri);
            }

            fprintf(fp, "%s", buf);
            fputc('\n', fp);
            funlockfile(fp);
            fclose(fp);
        }
    }
}

// Return fake connection structure. Used for logging, if connection
// is not applicable at the moment of logging.
static struct mg_connection *fc(struct mg_context *ctx) {
    static struct mg_connection fake_connection;
    fake_connection.ctx = ctx;
    return &fake_connection;
}

struct mg_request_info *mg_get_request_info(struct mg_connection *conn) {
    return &conn->request_info;
}

static void mg_strlcpy(register char *dst, register const char *src, size_t n) {
    for(; *src != '\0' && n > 1; n--) {
        *dst++ = *src++;
    }
    *dst = '\0';
}

static int lowercase(const char *s) {
    return tolower(* (const unsigned char *) s);
}

// Like snprintf(), but never returns negative value, or a value
// that is larger than a supplied buffer.
// Thanks to Adam Zeldis to pointing snprintf()-caused vulnerability
// in his audit report.
static int mg_vsnprintf(struct mg_connection *conn, char *buf, size_t buflen,
                        const char *fmt, va_list ap) {
    int n;

    if(buflen == 0)
        return 0;

    n = vsnprintf(buf, buflen, fmt, ap);

    if(n < 0) {
        cry(conn, "vsnprintf error");
        n = 0;
    } else if(n >= (int) buflen) {
        cry(conn, "truncating vsnprintf buffer: [%.*s]",
                n > 200 ? 200 : n, buf);
        n = (int) buflen - 1;
    }
    buf[n] = '\0';

    return n;
}

static int mg_snprintf(struct mg_connection *conn, char *buf, size_t buflen,
                       const char *fmt, ...) PRINTF_ARGS(4, 5);

static int mg_snprintf(struct mg_connection *conn, char *buf, size_t buflen,
                       const char *fmt, ...) {
    va_list ap;
    int n;

    va_start(ap, fmt);
    n = mg_vsnprintf(conn, buf, buflen, fmt, ap);
    va_end(ap);

    return n;
}

// Skip the characters until one of the delimiters characters found.
// 0-terminate resulting word. Skip the delimiter and following whitespaces.
// Advance pointer to buffer to the next word. Return found 0-terminated word.
// Delimiters can be quoted with quotechar.
static char *skip_quoted(char **buf, const char *delimiters,
                         const char *whitespace, char quotechar) {
    char *p, *begin_word, *end_word, *end_whitespace;

    begin_word = *buf;
    end_word = begin_word + strcspn(begin_word, delimiters);

    // Check for quotechar
    if(end_word > begin_word) {
        p = end_word - 1;
        while(*p == quotechar) {
            // If there is anything beyond end_word, copy it
            if(*end_word == '\0') {
                *p = '\0';
                break;
            } else {
                size_t end_off = strcspn(end_word + 1, delimiters);
                memmove (p, end_word, end_off + 1);
                p += end_off; // p must correspond to end_word - 1
                end_word += end_off + 1;
            }
        }
        for(p++; p < end_word; p++) {
            *p = '\0';
        }
    }

    if(*end_word == '\0') {
        *buf = end_word;
    } else {
        end_whitespace = end_word + 1 + strspn(end_word + 1, whitespace);

        for(p = end_word; p < end_whitespace; p++) {
            *p = '\0';
        }

        *buf = end_whitespace;
    }

    return begin_word;
}

// Simplified version of skip_quoted without quote char
// and whitespace == delimiters
static char *skip(char **buf, const char *delimiters) {
    return skip_quoted(buf, delimiters, delimiters, 0);
}


// Return HTTP header value, or NULL if not found.
static const char *get_header(const struct mg_request_info *ri,
                              const char *name) {
    int i;

    for(i = 0; i < ri->num_headers; i++)
        if(!strcasecmp(name, ri->http_headers[i].name))
            return ri->http_headers[i].value;

    return NULL;
}

const char *mg_get_header(const struct mg_connection *conn, const char *name) {
    return get_header(&conn->request_info, name);
}

// A helper function for traversing a comma separated list of values.
// It returns a list pointer shifted to the next value, or NULL if the end
// of the list found.
// Value is stored in val vector. If value has form "x=y", then eq_val
// vector is initialized to point to the "y" part, and val vector length
// is adjusted to point only to "x".
static const char *next_option(const char *list, struct vec *val,
                               struct vec *eq_val) {
    if(list == NULL || *list == '\0') {
        // End of the list
        list = NULL;
    } else {
        val->ptr = list;
        if((list = strchr(val->ptr, ',')) != NULL) {
            // Comma found. Store length and shift the list ptr
            val->len = list - val->ptr;
            list++;
        } else {
            // This value is the last one
            list = val->ptr + strlen(val->ptr);
            val->len = list - val->ptr;
        }

        if(eq_val != NULL) {
            // Value has form "x=y", adjust pointers and lengths
            // so that val points to "x", and eq_val points to "y".
            eq_val->len = 0;
            eq_val->ptr = (const char *) memchr(val->ptr, '=', val->len);
            if(eq_val->ptr != NULL) {
                eq_val->ptr++;    // Skip over '=' character
                eq_val->len = val->ptr + val->len - eq_val->ptr;
                val->len = (eq_val->ptr - val->ptr) - 1;
            }
        }
    }

    return list;
}

// Perform case-insensitive match of string against pattern
static int match_prefix(const char *pattern, int pattern_len, const char *str) {
    const char *or_str;
    int i, j, len, res;

    if((or_str = (const char *) memchr(pattern, '|', pattern_len)) != NULL) {
        res = match_prefix(pattern, or_str - pattern, str);
        return res > 0 ? res :
                match_prefix(or_str + 1, (pattern + pattern_len) - (or_str + 1), str);
    }

    i = j = 0;
    for(; i < pattern_len; i++, j++) {
        if(pattern[i] == '?' && str[j] != '\0') {
            continue;
        } else if(pattern[i] == '$') {
            return str[j] == '\0' ? j : -1;
        } else if(pattern[i] == '*') {
            i++;
            if(pattern[i] == '*') {
                i++;
                len = (int) strlen(str + j);
            } else {
                len = (int) strcspn(str + j, "/");
            }
            if(i == pattern_len) {
                return j + len;
            }
            do {
                res = match_prefix(pattern + i, pattern_len - i, str + j + len);
            } while(res == -1 && len-- > 0);
            return res == -1 ? -1 : j + res + len;
        } else if(lowercase(&pattern[i]) != lowercase(&str[j])) {
            return -1;
        }
    }
    return j;
}

// HTTP 1.1 assumes keep alive if "Connection:" header is not set
// This function must tolerate situations when connection info is not
// set up, for example if request parsing failed.
static int should_keep_alive(const struct mg_connection *conn) {
    const char *http_version = conn->request_info.http_version;
    const char *header = mg_get_header(conn, "Connection");
    if(conn->must_close ||
            conn->status_code == 401 ||
            strcasecmp(conn->ctx->config[ENABLE_KEEP_ALIVE], "yes") != 0 ||
            (header != NULL && strcasecmp(header, "keep-alive") != 0) ||
            (header == NULL && http_version && strncmp(http_version, "1.1", 3))) {
        return 0;
    }
    return 1;
}

static const char *suggest_connection_header(const struct mg_connection *conn) {
    return should_keep_alive(conn) ? "keep-alive" : "close";
}

static void send_http_error(struct mg_connection *, int, const char *,
                            const char *fmt, ...) PRINTF_ARGS(4, 5);


static void send_http_error(struct mg_connection *conn, int status,
                            const char *reason, const char *fmt, ...) {
    char buf[MG_BUF_LEN];
    va_list ap;
    int len = 0;

    conn->status_code = status;
    if(conn->ctx->callbacks.http_error == NULL ||
            conn->ctx->callbacks.http_error(conn, status)) {
        buf[0] = '\0';

        // Errors 1xx, 204 and 304 MUST NOT send a body
        if(status > 199 && status != 204 && status != 304) {
            len = mg_snprintf(conn, buf, sizeof(buf), "Error %d: %s", status, reason);
            buf[len++] = '\n';

            va_start(ap, fmt);
            len += mg_vsnprintf(conn, buf + len, sizeof(buf) - len, fmt, ap);
            va_end(ap);
        }
        DEBUG_TRACE(("[%s]", buf));

        mg_printf(conn, "HTTP/1.1 %d %s\r\n"
                            "Content-Length: %d\r\n"
                            "Connection: %s\r\n\r\n", status, reason, len,
                            suggest_connection_header(conn));
        conn->num_bytes_sent += mg_printf(conn, "%s", buf);
    }
}

static int mg_stat(struct mg_connection *conn, const char *path,
                   struct file *filep) {
    struct stat st;

    if(!is_file_in_memory(conn, path, filep) && !stat(path, &st)) {
        filep->size = st.st_size;
        filep->modification_time = st.st_mtime;
        filep->is_directory = S_ISDIR(st.st_mode);
    } else {
        filep->modification_time = (time_t) 0;
    }

    return filep->membuf != NULL || filep->modification_time != (time_t) 0;
}

static void set_close_on_exec(int fd) {
    fcntl(fd, F_SETFD, FD_CLOEXEC);
}

int mg_start_thread(mg_thread_func_t func, void *param) {
    pthread_t thread_id;
    pthread_attr_t attr;
    int result;

    (void) pthread_attr_init(&attr);
    (void) pthread_attr_setdetachstate(&attr, PTHREAD_CREATE_DETACHED);

#if USE_STACK_SIZE > 1
    // Compile-time option to control stack size, e.g. -DUSE_STACK_SIZE=16384
    (void) pthread_attr_setstacksize(&attr, USE_STACK_SIZE);
#endif

    result = pthread_create(&thread_id, &attr, func, param);
    pthread_attr_destroy(&attr);

    return result;
}

static int set_non_blocking_mode(SOCKET sock) {
    int flags;

    flags = fcntl(sock, F_GETFL, 0);
    (void) fcntl(sock, F_SETFL, flags | O_NONBLOCK);

    return 0;
}

// Write data to the IO channel - opened file descriptor, socket or SSL
// descriptor. Return number of bytes written.
static int64_t push(FILE *fp, SOCKET sock, SSL *ssl, const char *buf,
                    int64_t len) {
    int64_t sent;
    int n, k;

    (void) ssl;    // Get rid of warning
    sent = 0;
    while(sent < len) {

        // How many bytes we send in this iteration
        k = len - sent > INT_MAX ? INT_MAX : (int) (len - sent);

        if(ssl != NULL) {
            n = SSL_write(ssl, buf + sent, k);
        } else
            if(fp != NULL) {
            n = (int) fwrite(buf + sent, 1, (size_t) k, fp);
            if(ferror(fp))
                n = -1;
        } else {
            n = send(sock, buf + sent, (size_t) k, MSG_NOSIGNAL);
        }

        if(n <= 0)
            break;

        sent += n;
    }

    return sent;
}

// Read from IO channel - opened file descriptor, socket, or SSL descriptor.
// Return negative value on error, or number of bytes read on success.
static int pull(FILE *fp, struct mg_connection *conn, char *buf, int len) {
    int nread;

    if(fp != NULL) {
        // Use read() instead of fread(), because if we're reading from the CGI
        // pipe, fread() may block until IO buffer is filled up. We cannot afford
        // to block and must pass all read bytes immediately to the client.
        nread = read(fileno(fp), buf, (size_t) len);
    } else if(conn->ssl != NULL) {
        nread = SSL_read(conn->ssl, buf, len);
    } else {
        nread = recv(conn->client.sock, buf, (size_t) len, 0);
    }

    return conn->ctx->stop_flag ? -1 : nread;
}

static int pull_all(FILE *fp, struct mg_connection *conn, char *buf, int len) {
    int n, nread = 0;

    while(len > 0 && conn->ctx->stop_flag == 0) {
        n = pull(fp, conn, buf + nread, len);
        if(n < 0) {
            nread = n;    // Propagate the error
            break;
        } else if(n == 0) {
            break;    // No more data to read
        } else {
            conn->consumed_content += n;
            nread += n;
            len -= n;
        }
    }

    return nread;
}

int mg_read(struct mg_connection *conn, void *buf, size_t len) {
    int n, buffered_len, nread;
    const char *body;

    // If Content-Length is not set, read until socket is closed
    if(conn->consumed_content == 0 && conn->content_len == 0) {
        conn->content_len = INT64_MAX;
        conn->must_close = 1;
    }

    nread = 0;
    if(conn->consumed_content < conn->content_len) {
        // Adjust number of bytes to read.
        int64_t to_read = conn->content_len - conn->consumed_content;
        if(to_read < (int64_t) len) {
            len = (size_t) to_read;
        }

        // Return buffered data
        body = conn->buf + conn->request_len + conn->consumed_content;
        buffered_len = &conn->buf[conn->data_len] - body;
        if(buffered_len > 0) {
            if(len < (size_t) buffered_len) {
                buffered_len = (int) len;
            }
            memcpy(buf, body, (size_t) buffered_len);
            len -= buffered_len;
            conn->consumed_content += buffered_len;
            nread += buffered_len;
            buf = (char *) buf + buffered_len;
        }

        // We have returned all buffered data. Read new data from the remote socket.
        n = pull_all(NULL, conn, (char *) buf, (int) len);
        nread = n >= 0 ? nread + n : n;
    }
    return nread;
}

int mg_write(struct mg_connection *conn, const void *buf, size_t len) {
    time_t now;
    int64_t n, total, allowed;

    if(conn->throttle > 0) {
        if((now = time(NULL)) != conn->last_throttle_time) {
            conn->last_throttle_time = now;
            conn->last_throttle_bytes = 0;
        }
        allowed = conn->throttle - conn->last_throttle_bytes;
        if(allowed > (int64_t) len) {
            allowed = len;
        }
        if((total = push(NULL, conn->client.sock, conn->ssl, (const char *) buf,
                                            (int64_t) allowed)) == allowed) {
            buf = (char *) buf + total;
            conn->last_throttle_bytes += total;
            while(total < (int64_t) len && conn->ctx->stop_flag == 0) {
                allowed = conn->throttle > (int64_t) len - total ?
                    (int64_t) len - total : conn->throttle;
                if((n = push(NULL, conn->client.sock, conn->ssl, (const char *) buf,
                                            (int64_t) allowed)) != allowed) {
                    break;
                }
                sleep(1);
                conn->last_throttle_bytes = allowed;
                conn->last_throttle_time = time(NULL);
                buf = (char *) buf + n;
                total += n;
            }
        }
    } else {
        total = push(NULL, conn->client.sock, conn->ssl, (const char *) buf,
                                 (int64_t) len);
    }
    return (int) total;
}

// Alternative alloc_vprintf() for non-compliant C runtimes
static int alloc_vprintf2(char **buf, const char *fmt, va_list ap) {
    va_list ap_copy;
    int size = MG_BUF_LEN;
    int len = -1;

    *buf = NULL;
    while(len == -1) {
        if(*buf) free(*buf);
        *buf = malloc(size *= 4);
        if(!*buf) break;
        va_copy(ap_copy, ap);
        len = vsnprintf(*buf, size, fmt, ap_copy);
    }

    return len;
}

// Print message to buffer. If buffer is large enough to hold the message,
// return buffer. If buffer is to small, allocate large enough buffer on heap,
// and return allocated buffer.
static int alloc_vprintf(char **buf, size_t size, const char *fmt, va_list ap) {
    va_list ap_copy;
    int len;

    // Windows is not standard-compliant, and vsnprintf() returns -1 if
    // buffer is too small. Also, older versions of msvcrt.dll do not have
    // _vscprintf().    However, if size is 0, vsnprintf() behaves correctly.
    // Therefore, we make two passes: on first pass, get required message length.
    // On second pass, actually print the message.
    va_copy(ap_copy, ap);
    len = vsnprintf(NULL, 0, fmt, ap_copy);

    if(len < 0) {
        // C runtime is not standard compliant, vsnprintf() returned -1.
        // Switch to alternative code path that uses incremental allocations.
        va_copy(ap_copy, ap);
        len = alloc_vprintf2(buf, fmt, ap);
    } else if(len > (int) size &&
            (size = len + 1) > 0 &&
            (*buf = (char *) malloc(size)) == NULL) {
        len = -1;    // Allocation failed, mark failure
    } else {
        va_copy(ap_copy, ap);
        vsnprintf(*buf, size, fmt, ap_copy);
    }

    return len;
}

int mg_vprintf(struct mg_connection *conn, const char *fmt, va_list ap) {
    char mem[MG_BUF_LEN], *buf = mem;
    int len;

    if((len = alloc_vprintf(&buf, sizeof(mem), fmt, ap)) > 0) {
        len = mg_write(conn, buf, (size_t) len);
    }
    if(buf != mem && buf != NULL) {
        free(buf);
    }

    return len;
}

int mg_printf(struct mg_connection *conn, const char *fmt, ...) {
    va_list ap;
    va_start(ap, fmt);
    return mg_vprintf(conn, fmt, ap);
}

int mg_url_decode(const char *src, int src_len, char *dst,
                  int dst_len, int is_form_url_encoded) {
    int i, j, a, b;
#define HEXTOI(x) (isdigit(x) ? x - '0' : x - 'W')

    for(i = j = 0; i < src_len && j < dst_len - 1; i++, j++) {
        if(src[i] == '%' && i < src_len - 2 &&
                isxdigit(* (const unsigned char *) (src + i + 1)) &&
                isxdigit(* (const unsigned char *) (src + i + 2))) {
            a = tolower(* (const unsigned char *) (src + i + 1));
            b = tolower(* (const unsigned char *) (src + i + 2));
            dst[j] = (char) ((HEXTOI(a) << 4) | HEXTOI(b));
            i += 2;
        } else if(is_form_url_encoded && src[i] == '+') {
            dst[j] = ' ';
        } else {
            dst[j] = src[i];
        }
    }

    dst[j] = '\0'; // Null-terminate the destination

    return i >= src_len ? j : -1;
}

int mg_get_var(const char *data, size_t data_len, const char *name,
               char *dst, size_t dst_len) {
    const char *p, *e, *s;
    size_t name_len;
    int len;

    if(dst == NULL || dst_len == 0) {
        len = -2;
    } else if(data == NULL || name == NULL || data_len == 0) {
        len = -1;
        dst[0] = '\0';
    } else {
        name_len = strlen(name);
        e = data + data_len;
        len = -1;
        dst[0] = '\0';

        // data is "var1=val1&var2=val2...". Find variable first
        for(p = data; p + name_len < e; p++) {
            if((p == data || p[-1] == '&') && p[name_len] == '=' &&
                    !strncasecmp(name, p, name_len)) {

                // Point p to variable value
                p += name_len + 1;

                // Point s to the end of the value
                s = (const char *) memchr(p, '&', (size_t)(e - p));
                if(s == NULL) {
                    s = e;
                }
                assert(s >= p);

                // Decode variable into destination buffer
                len = mg_url_decode(p, (size_t)(s - p), dst, dst_len, 1);

                // Redirect error code from -1 to -2 (destination buffer too small).
                if(len == -1) {
                    len = -2;
                }
                break;
            }
        }
    }

    return len;
}

int mg_get_cookie(const char *cookie_header, const char *var_name,
                  char *dst, size_t dst_size) {
    const char *s, *p, *end;
    int name_len, len = -1;

    if(dst == NULL || dst_size == 0) {
        len = -2;
    } else if(var_name == NULL || (s = cookie_header) == NULL) {
        len = -1;
        dst[0] = '\0';
    } else {
        name_len = (int) strlen(var_name);
        end = s + strlen(s);
        dst[0] = '\0';

        for(; (s = strcasestr(s, var_name)) != NULL; s += name_len) {
            if(s[name_len] == '=') {
                s += name_len + 1;
                if((p = strchr(s, ' ')) == NULL)
                    p = end;
                if(p[-1] == ';')
                    p--;
                if(*s == '"' && p[-1] == '"' && p > s + 1) {
                    s++;
                    p--;
                }
                if((size_t) (p - s) < dst_size) {
                    len = p - s;
                    mg_strlcpy(dst, s, (size_t) len + 1);
                } else {
                    len = -3;
                }
                break;
            }
        }
    }
    return len;
}

static void convert_uri_to_file_name(struct mg_connection *conn, char *buf,
                                     size_t buf_len, struct file *filep) {
    struct vec a, b;
    const char *rewrite, *uri = conn->request_info.uri,
                *root = conn->ctx->config[DOCUMENT_ROOT];
    int match_len;
    char gz_path[PATH_MAX];
    char const* accept_encoding;

    // Using buf_len - 1 because memmove() for PATH_INFO may shift part
    // of the path one byte on the right.
    // If document_root is NULL, leave the file empty.
    mg_snprintf(conn, buf, buf_len - 1, "%s%s",
                            root == NULL ? "" : root,
                            root == NULL ? "" : uri);

    rewrite = conn->ctx->config[REWRITE];
    while((rewrite = next_option(rewrite, &a, &b)) != NULL) {
        if((match_len = match_prefix(a.ptr, a.len, uri)) > 0) {
            mg_snprintf(conn, buf, buf_len - 1, "%.*s%s", (int) b.len, b.ptr,
                                    uri + match_len);
            break;
        }
    }

    if(mg_stat(conn, buf, filep)) return;

    // if we can't find the actual file, look for the file
    // with the same name but a .gz extension. If we find it,
    // use that and set the gzipped flag in the file struct
    // to indicate that the response need to have the content-
    // encoding: gzip header
    // we can only do this if the browser declares support
    if((accept_encoding = mg_get_header(conn, "Accept-Encoding")) != NULL) {
        if(strstr(accept_encoding,"gzip") != NULL) {
            snprintf(gz_path, sizeof(gz_path), "%s.gz", buf);
            if(mg_stat(conn, gz_path, filep)) {
                filep->gzipped = 1;
                return;
            }
        }
    }
}

// Check whether full request is buffered. Return:
//     -1    if request is malformed
//        0    if request is not yet fully buffered
//     >0    actual request length, including last \r\n\r\n
static int get_request_len(const char *buf, int buflen) {
    const char *s, *e;
    int len = 0;

    for(s = buf, e = s + buflen - 1; len <= 0 && s < e; s++)
        // Control characters are not allowed but >=128 is.
        if(!isprint(* (const unsigned char *) s) && *s != '\r' &&
                *s != '\n' && * (const unsigned char *) s < 128) {
            len = -1;
            break;    // [i_a] abort scan as soon as one malformed character is found;
                            // don't let subsequent \r\n\r\n win us over anyhow
        } else if(s[0] == '\n' && s[1] == '\n') {
            len = (int) (s - buf) + 2;
        } else if(s[0] == '\n' && &s[1] < e &&
                s[1] == '\r' && s[2] == '\n') {
            len = (int) (s - buf) + 3;
        }

    return len;
}

// Convert month to the month number. Return -1 on error, or month number
static int get_month_index(const char *s) {
    size_t i;

    for(i = 0; i < ARRAY_SIZE(month_names); i++)
        if(!strcmp(s, month_names[i]))
            return (int) i;

    return -1;
}

static int num_leap_years(int year) {
    return year / 4 - year / 100 + year / 400;
}

// Parse UTC date-time string, and return the corresponding time_t value.
static time_t parse_date_string(const char *datetime) {
    static const unsigned short days_before_month[] = {
        0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334
    };
    char month_str[32];
    int second, minute, hour, day, month, year, leap_days, days;
    time_t result = (time_t) 0;

    if(((sscanf(datetime, "%d/%3s/%d %d:%d:%d",
                             &day, month_str, &year, &hour, &minute, &second) == 6) ||
             (sscanf(datetime, "%d %3s %d %d:%d:%d",
                             &day, month_str, &year, &hour, &minute, &second) == 6) ||
             (sscanf(datetime, "%*3s, %d %3s %d %d:%d:%d",
                             &day, month_str, &year, &hour, &minute, &second) == 6) ||
             (sscanf(datetime, "%d-%3s-%d %d:%d:%d",
                             &day, month_str, &year, &hour, &minute, &second) == 6)) &&
            year > 1970 &&
            (month = get_month_index(month_str)) != -1) {
        leap_days = num_leap_years(year) - num_leap_years(1970);
        year -= 1970;
        days = year * 365 + days_before_month[month] + (day - 1) + leap_days;
        result = days * 24 * 3600 + hour * 3600 + minute * 60 + second;
    }

    return result;
}

// Protect against directory disclosure attack by removing '..',
// excessive '/' and '\' characters
static void remove_double_dots_and_double_slashes(char *s) {
    char *p = s;

    while(*s != '\0') {
        *p++ = *s++;
        if(s[-1] == '/' || s[-1] == '\\') {
            // Skip all following slashes, backslashes and double-dots
            while(s[0] != '\0') {
                if(s[0] == '/' || s[0] == '\\') {
                    s++;
                } else if(s[0] == '.' && s[1] == '.') {
                    s += 2;
                } else {
                    break;
                }
            }
        }
    }
    *p = '\0';
}

static const struct {
    const char *extension;
    size_t ext_len;
    const char *mime_type;
} builtin_mime_types[] = {
    {".html", 5, "text/html"},
    {".htm", 4, "text/html"},
    {".shtm", 5, "text/html"},
    {".shtml", 6, "text/html"},
    {".css", 4, "text/css"},
    {".js",    3, "application/x-javascript"},
    {".ico", 4, "image/x-icon"},
    {".gif", 4, "image/gif"},
    {".jpg", 4, "image/jpeg"},
    {".jpeg", 5, "image/jpeg"},
    {".png", 4, "image/png"},
    {".svg", 4, "image/svg+xml"},
    {".txt", 4, "text/plain"},
    {".torrent", 8, "application/x-bittorrent"},
    {".wav", 4, "audio/x-wav"},
    {".mp3", 4, "audio/x-mp3"},
    {".mid", 4, "audio/mid"},
    {".m3u", 4, "audio/x-mpegurl"},
    {".ogg", 4, "audio/ogg"},
    {".ram", 4, "audio/x-pn-realaudio"},
    {".xml", 4, "text/xml"},
    {".json",    5, "text/json"},
    {".xslt", 5, "application/xml"},
    {".xsl", 4, "application/xml"},
    {".ra",    3, "audio/x-pn-realaudio"},
    {".doc", 4, "application/msword"},
    {".exe", 4, "application/octet-stream"},
    {".zip", 4, "application/x-zip-compressed"},
    {".xls", 4, "application/excel"},
    {".tgz", 4, "application/x-tar-gz"},
    {".tar", 4, "application/x-tar"},
    {".gz",    3, "application/x-gunzip"},
    {".arj", 4, "application/x-arj-compressed"},
    {".rar", 4, "application/x-arj-compressed"},
    {".rtf", 4, "application/rtf"},
    {".pdf", 4, "application/pdf"},
    {".swf", 4, "application/x-shockwave-flash"},
    {".mpg", 4, "video/mpeg"},
    {".webm", 5, "video/webm"},
    {".mpeg", 5, "video/mpeg"},
    {".mov", 4, "video/quicktime"},
    {".mp4", 4, "video/mp4"},
    {".m4v", 4, "video/x-m4v"},
    {".asf", 4, "video/x-ms-asf"},
    {".avi", 4, "video/x-msvideo"},
    {".bmp", 4, "image/bmp"},
    {".ttf", 4, "application/x-font-ttf"},
    {NULL,    0, NULL}
};

const char *mg_get_builtin_mime_type(const char *path) {
    const char *ext;
    size_t i, path_len;

    path_len = strlen(path);

    for(i = 0; builtin_mime_types[i].extension != NULL; i++) {
        ext = path + (path_len - builtin_mime_types[i].ext_len);
        if(path_len > builtin_mime_types[i].ext_len &&
                strcasecmp(ext, builtin_mime_types[i].extension) == 0) {
            return builtin_mime_types[i].mime_type;
        }
    }

    return "text/plain";
}

// Look at the "path" extension and figure what mime type it has.
// Store mime type in the vector.
static void get_mime_type(struct mg_context *ctx, const char *path,
                          struct vec *vec) {
    struct vec ext_vec, mime_vec;
    const char *list, *ext;
    size_t path_len;

    path_len = strlen(path);

    // Scan user-defined mime types first, in case user wants to
    // override default mime types.
    list = ctx->config[EXTRA_MIME_TYPES];
    while((list = next_option(list, &ext_vec, &mime_vec)) != NULL) {
        // ext now points to the path suffix
        ext = path + path_len - ext_vec.len;
        if(strncasecmp(ext, ext_vec.ptr, ext_vec.len) == 0) {
            *vec = mime_vec;
            return;
        }
    }

    vec->ptr = mg_get_builtin_mime_type(path);
    vec->len = strlen(vec->ptr);
}

// Stringify binary data. Output buffer must be twice as big as input,
// because each byte takes 2 bytes in string representation
static void bin2str(char *to, const unsigned char *p, size_t len) {
    static const char *hex = "0123456789abcdef";

    for(; len--; p++) {
        *to++ = hex[p[0] >> 4];
        *to++ = hex[p[0] & 0x0f];
    }
    *to = '\0';
}

// Return stringified MD5 hash for list of strings. Buffer must be 33 bytes.
char *mg_md5(char buf[33], ...) {
    unsigned char hash[16];
    const char *p;
    va_list ap;
    MD5_CTX ctx;

    MD5_Init(&ctx);

    va_start(ap, buf);
    while((p = va_arg(ap, const char *)) != NULL) {
        MD5_Update(&ctx, (const unsigned char *) p, (unsigned) strlen(p));
    }
    va_end(ap);

    MD5_Final(hash, &ctx);
    bin2str(buf, hash, sizeof(hash));
    return buf;
}

// Check the user's password, return 1 if OK
static int check_password(const char *method, const char *ha1, const char *uri,
                          const char *nonce, const char *nc, const char *cnonce,
                          const char *qop, const char *response) {
    char ha2[32 + 1], expected_response[32 + 1];

    // Some of the parameters may be NULL
    if(method == NULL || nonce == NULL || nc == NULL || cnonce == NULL ||
            qop == NULL || response == NULL) {
        return 0;
    }

    // NOTE(lsm): due to a bug in MSIE, we do not compare the URI
    // TODO(lsm): check for authentication timeout
    if(// strcmp(dig->uri, c->ouri) != 0 ||
            strlen(response) != 32
            // || now - strtoul(dig->nonce, NULL, 10) > 3600
            ) {
        return 0;
    }

    mg_md5(ha2, method, ":", uri, NULL);
    mg_md5(expected_response, ha1, ":", nonce, ":", nc,
            ":", cnonce, ":", qop, ":", ha2, NULL);

    return strcasecmp(response, expected_response) == 0;
}

// Use the global passwords file, if specified by auth_gpass option,
// or search for .htpasswd in the requested directory.
static void open_auth_file(struct mg_connection *conn, const char *path,
                           struct file *filep) {
    char name[PATH_MAX];
    const char *p, *e, *gpass = conn->ctx->config[GLOBAL_PASSWORDS_FILE];
    struct file file = STRUCT_FILE_INITIALIZER;

    if(gpass != NULL) {
        // Use global passwords file
        if(!mg_fopen(conn, gpass, "r", filep)) {
            cry(conn, "fopen(%s): %s", gpass, strerror(errno));
        }
        // Important: using local struct file to test path for is_directory flag.
        // If filep is used, mg_stat() makes it appear as if auth file was opened.
    } else if(mg_stat(conn, path, &file) && file.is_directory) {
        mg_snprintf(conn, name, sizeof(name), "%s%c%s",
                                path, '/', PASSWORDS_FILE_NAME);
        mg_fopen(conn, name, "r", filep);
    } else {
         // Try to find .htpasswd in requested directory.
        for(p = path, e = p + strlen(p) - 1; e > p; e--)
            if(e[0] == '/')
                break;
        mg_snprintf(conn, name, sizeof(name), "%.*s%c%s",
                                (int) (e - p), p, '/', PASSWORDS_FILE_NAME);
        mg_fopen(conn, name, "r", filep);
    }
}

// Parsed Authorization header
struct ah {
    char *user, *uri, *cnonce, *response, *qop, *nc, *nonce;
};

// Return 1 on success. Always initializes the ah structure.
static int parse_auth_header(struct mg_connection *conn, char *buf,
                             size_t buf_size, struct ah *ah) {
    char *name, *value, *s;
    const char *auth_header;

    (void) memset(ah, 0, sizeof(*ah));
    if((auth_header = mg_get_header(conn, "Authorization")) == NULL ||
            strncasecmp(auth_header, "Digest ", 7) != 0) {
        return 0;
    }

    // Make modifiable copy of the auth header
    (void) mg_strlcpy(buf, auth_header + 7, buf_size);
    s = buf;

    // Parse authorization header
    for(;;) {
        // Gobble initial spaces
        while(isspace(* (unsigned char *) s)) {
            s++;
        }
        name = skip_quoted(&s, "=", " ", 0);
        // Value is either quote-delimited, or ends at first comma or space.
        if(s[0] == '\"') {
            s++;
            value = skip_quoted(&s, "\"", " ", '\\');
            if(s[0] == ',') {
                s++;
            }
        } else {
            value = skip_quoted(&s, ", ", " ", 0);    // IE uses commas, FF uses spaces
        }
        if(*name == '\0') {
            break;
        }

        if(!strcmp(name, "username")) {
            ah->user = value;
        } else if(!strcmp(name, "cnonce")) {
            ah->cnonce = value;
        } else if(!strcmp(name, "response")) {
            ah->response = value;
        } else if(!strcmp(name, "uri")) {
            ah->uri = value;
        } else if(!strcmp(name, "qop")) {
            ah->qop = value;
        } else if(!strcmp(name, "nc")) {
            ah->nc = value;
        } else if(!strcmp(name, "nonce")) {
            ah->nonce = value;
        }
    }

    // CGI needs it as REMOTE_USER
    if(ah->user != NULL) {
        conn->request_info.remote_user = strdup(ah->user);
    } else {
        return 0;
    }

    return 1;
}

static char *mg_fgets(char *buf, size_t size, struct file *filep, char **p) {
    char *eof;
    size_t len;
    char *memend;

    if(filep->membuf != NULL && *p != NULL) {
        memend = (char *) &filep->membuf[filep->size];
        eof = (char *) memchr(*p, '\n', memend - *p); // Search for \n from p till the end of stream
        if(eof != NULL) {
            eof += 1; // Include \n
        } else {
            eof = memend; // Copy remaining data
        }
        len = (size_t) (eof - *p) > size - 1 ? size - 1 : (size_t) (eof - *p);    
        memcpy(buf, *p, len);
        buf[len] = '\0';
        *p += len;
        return len ? eof : NULL;
    } else if(filep->fp != NULL) {
        return fgets(buf, size, filep->fp);
    } else {
        return NULL;
    }
}

// Authorize against the opened passwords file. Return 1 if authorized.
static int authorize(struct mg_connection *conn, struct file *filep) {
    struct ah ah;
    char line[256], f_user[256], ha1[256], f_domain[256], buf[MG_BUF_LEN], *p;

    if(!parse_auth_header(conn, buf, sizeof(buf), &ah)) {
        return 0;
    }

    // Loop over passwords file
    p = (char *) filep->membuf;
    while(mg_fgets(line, sizeof(line), filep, &p) != NULL) {
        if(sscanf(line, "%[^:]:%[^:]:%s", f_user, f_domain, ha1) != 3) {
            continue;
        }

        if(!strcmp(ah.user, f_user) &&
                !strcmp(conn->ctx->config[AUTHENTICATION_DOMAIN], f_domain))
            return check_password(conn->request_info.request_method, ha1, ah.uri,
                                                        ah.nonce, ah.nc, ah.cnonce, ah.qop, ah.response);
    }

    return 0;
}

// Return 1 if request is authorised, 0 otherwise.
static int check_authorization(struct mg_connection *conn, const char *path) {
    char fname[PATH_MAX];
    struct vec uri_vec, filename_vec;
    const char *list;
    struct file file = STRUCT_FILE_INITIALIZER;
    int authorized = 1;

    list = conn->ctx->config[PROTECT_URI];
    while((list = next_option(list, &uri_vec, &filename_vec)) != NULL) {
        if(!memcmp(conn->request_info.uri, uri_vec.ptr, uri_vec.len)) {
            mg_snprintf(conn, fname, sizeof(fname), "%.*s",
                                    (int) filename_vec.len, filename_vec.ptr);
            if(!mg_fopen(conn, fname, "r", &file)) {
                cry(conn, "%s: cannot open %s: %s", __func__, fname, strerror(errno));
            }
            break;
        }
    }

    if(!is_file_opened(&file)) {
        open_auth_file(conn, path, &file);
    }

    if(is_file_opened(&file)) {
        authorized = authorize(conn, &file);
        mg_fclose(&file);
    }

    return authorized;
}

static void send_authorization_request(struct mg_connection *conn) {
    conn->status_code = 401;
    mg_printf(conn,
                        "HTTP/1.1 401 Unauthorized\r\n"
                        "Content-Length: 0\r\n"
                        "WWW-Authenticate: Digest qop=\"auth\", "
                        "realm=\"%s\", nonce=\"%lu\"\r\n\r\n",
                        conn->ctx->config[AUTHENTICATION_DOMAIN],
                        (unsigned long) time(NULL));
}

static int is_authorized_for_put(struct mg_connection *conn) {
    struct file file = STRUCT_FILE_INITIALIZER;
    const char *passfile = conn->ctx->config[PUT_DELETE_PASSWORDS_FILE];
    int ret = 0;

    if(passfile != NULL && mg_fopen(conn, passfile, "r", &file)) {
        ret = authorize(conn, &file);
        mg_fclose(&file);
    }

    return ret;
}

int mg_modify_passwords_file(const char *fname, const char *domain,
                             const char *user, const char *pass) {
    int found;
    char line[512], u[512], d[512], ha1[33], tmp[PATH_MAX];
    FILE *fp, *fp2;

    found = 0;
    fp = fp2 = NULL;

    // Regard empty password as no password - remove user record.
    if(pass != NULL && pass[0] == '\0') {
        pass = NULL;
    }

    (void) snprintf(tmp, sizeof(tmp), "%s.tmp", fname);

    // Create the file if does not exist
    if((fp = fopen(fname, "a+")) != NULL) {
        (void) fclose(fp);
    }

    // Open the given file and temporary file
    if((fp = fopen(fname, "r")) == NULL) {
        return 0;
    } else if((fp2 = fopen(tmp, "w+")) == NULL) {
        fclose(fp);
        return 0;
    }

    // Copy the stuff to temporary file
    while(fgets(line, sizeof(line), fp) != NULL) {
        if(sscanf(line, "%[^:]:%[^:]:%*s", u, d) != 2) {
            continue;
        }

        if(!strcmp(u, user) && !strcmp(d, domain)) {
            found++;
            if(pass != NULL) {
                mg_md5(ha1, user, ":", domain, ":", pass, NULL);
                fprintf(fp2, "%s:%s:%s\n", user, domain, ha1);
            }
        } else {
            fprintf(fp2, "%s", line);
        }
    }

    // If new user, just add it
    if(!found && pass != NULL) {
        mg_md5(ha1, user, ":", domain, ":", pass, NULL);
        fprintf(fp2, "%s:%s:%s\n", user, domain, ha1);
    }

    // Close files
    fclose(fp);
    fclose(fp2);

    // Put the temp file in place of real file
    remove(fname);
    rename(tmp, fname);

    return 1;
}

static SOCKET conn2(const char *host, int port, int use_ssl,
                    char *ebuf, size_t ebuf_len) {
    struct sockaddr_in sin;
    struct hostent *he;
    SOCKET sock = INVALID_SOCKET;

    if(host == NULL) {
        snprintf(ebuf, ebuf_len, "%s", "NULL host");
    } else if(use_ssl && SSLv23_client_method == NULL) {
        snprintf(ebuf, ebuf_len, "%s", "SSL is not initialized");
        // TODO(lsm): use something threadsafe instead of gethostbyname()
    } else if((he = gethostbyname(host)) == NULL) {
        snprintf(ebuf, ebuf_len, "gethostbyname(%s): %s", host, strerror(errno));
    } else if((sock = socket(PF_INET, SOCK_STREAM, 0)) == INVALID_SOCKET) {
        snprintf(ebuf, ebuf_len, "socket(): %s", strerror(errno));
    } else {
        set_close_on_exec(sock);
        sin.sin_family = AF_INET;
        sin.sin_port = htons((uint16_t) port);
        sin.sin_addr = * (struct in_addr *) he->h_addr_list[0];
        if(connect(sock, (struct sockaddr *) &sin, sizeof(sin)) != 0) {
            snprintf(ebuf, ebuf_len, "connect(%s:%d): %s",
                             host, port, strerror(errno));
            closesocket(sock);
            sock = INVALID_SOCKET;
        }
    }
    return sock;
}



void mg_url_encode(const char *src, char *dst, size_t dst_len) {
    static const char *dont_escape = "._-$,;~()";
    static const char *hex = "0123456789abcdef";
    const char *end = dst + dst_len - 1;

    for(; *src != '\0' && dst < end; src++, dst++) {
        if(isalnum(*(const unsigned char *) src) ||
                strchr(dont_escape, * (const unsigned char *) src) != NULL) {
            *dst = *src;
        } else if(dst + 2 < end) {
            dst[0] = '%';
            dst[1] = hex[(* (const unsigned char *) src) >> 4];
            dst[2] = hex[(* (const unsigned char *) src) & 0xf];
            dst += 2;
        }
    }

    *dst = '\0';
}

static void print_dir_entry(struct de *de) {
    char size[64], mod[64], href[PATH_MAX];

    if(de->file.is_directory) {
        mg_snprintf(de->conn, size, sizeof(size), "%s", "[DIRECTORY]");
    } else {
        if(de->file.size < 1024) {
            mg_snprintf(de->conn, size, sizeof(size), "%d", (int) de->file.size);
        } else if(de->file.size < 0x100000) {
            mg_snprintf(de->conn, size, sizeof(size),
                        "%.1fk", (double) de->file.size / 1024.0);
        } else if(de->file.size < 0x40000000) {
            mg_snprintf(de->conn, size, sizeof(size),
                        "%.1fM", (double) de->file.size / 1048576);
        } else {
            mg_snprintf(de->conn, size, sizeof(size),
                        "%.1fG", (double) de->file.size / 1073741824);
        }
    }
    strftime(mod, sizeof(mod), "%d-%b-%Y %H:%M",
                     localtime(&de->file.modification_time));
    mg_url_encode(de->file_name, href, sizeof(href));
    de->conn->num_bytes_sent += mg_printf(de->conn,
        "<tr><td><a href=\"%s%s%s\">%s%s</a></td>"
        "<td>&nbsp;%s</td><td>&nbsp;&nbsp;%s</td></tr>\n",
        de->conn->request_info.uri, href, de->file.is_directory ? "/" : "",
        de->file_name, de->file.is_directory ? "/" : "", mod, size);
}

// This function is called from send_directory() and used for
// sorting directory entries by size, or name, or modification time.
// On windows, __cdecl specification is needed in case if project is built
// with __stdcall convention. qsort always requires __cdels callback.
static int compare_dir_entries(const void *p1, const void *p2) {
    const struct de *a = (const struct de *) p1, *b = (const struct de *) p2;
    const char *query_string = a->conn->request_info.query_string;
    int cmp_result = 0;

    if(query_string == NULL) {
        query_string = "na";
    }

    if(a->file.is_directory && !b->file.is_directory) {
        return -1;    // Always put directories on top
    } else if(!a->file.is_directory && b->file.is_directory) {
        return 1;     // Always put directories on top
    } else if(*query_string == 'n') {
        cmp_result = strcmp(a->file_name, b->file_name);
    } else if(*query_string == 's') {
        cmp_result = a->file.size == b->file.size ? 0 :
            a->file.size > b->file.size ? 1 : -1;
    } else if(*query_string == 'd') {
        cmp_result = a->file.modification_time == b->file.modification_time
                     ? 0
                     : a->file.modification_time > b->file.modification_time ? 1 : -1;
    }

    return query_string[1] == 'd' ? -cmp_result : cmp_result;
}

static int must_hide_file(struct mg_connection *conn, const char *path) {
    const char *pw_pattern = "**" PASSWORDS_FILE_NAME "$";
    const char *pattern = conn->ctx->config[HIDE_FILES];
    return match_prefix(pw_pattern, strlen(pw_pattern), path) > 0 ||
        (pattern != NULL && match_prefix(pattern, strlen(pattern), path) > 0);
}

static int scan_directory(struct mg_connection *conn, const char *dir,
                          void *data, void (*cb)(struct de *, void *)) {
    char path[PATH_MAX];
    struct dirent *dp;
    DIR *dirp;
    struct de de;

    if((dirp = opendir(dir)) == NULL) {
        return 0;
    } else {
        de.conn = conn;

        while((dp = readdir(dirp)) != NULL) {
            // Do not show current dir and hidden files
            if(!strcmp(dp->d_name, ".") ||
                !strcmp(dp->d_name, "..") ||
                must_hide_file(conn, dp->d_name)) {
                continue;
            }

            mg_snprintf(conn, path, sizeof(path), "%s%c%s", dir, '/', dp->d_name);

            // If we don't memset stat structure to zero, mtime will have
            // garbage and strftime() will segfault later on in
            // print_dir_entry(). memset is required only if mg_stat()
            // fails. For more details, see
            // http://code.google.com/p/mongoose/issues/detail?id=79
            memset(&de.file, 0, sizeof(de.file));
            mg_stat(conn, path, &de.file);

            de.file_name = dp->d_name;
            cb(&de, data);
        }
        (void) closedir(dirp);
    }
    return 1;
}

static int remove_directory(struct mg_connection *conn, const char *dir) {
    char path[PATH_MAX];
    struct dirent *dp;
    DIR *dirp;
    struct de de;

    if((dirp = opendir(dir)) == NULL) {
        return 0;
    } else {
        de.conn = conn;

        while((dp = readdir(dirp)) != NULL) {
            // Do not show current dir (but show hidden files as they will also be removed)
            if(!strcmp(dp->d_name, ".") ||
               !strcmp(dp->d_name, "..")) {
                continue;
            }

            mg_snprintf(conn, path, sizeof(path), "%s%c%s", dir, '/', dp->d_name);

            // If we don't memset stat structure to zero, mtime will have
            // garbage and strftime() will segfault later on in
            // print_dir_entry(). memset is required only if mg_stat()
            // fails. For more details, see
            // http://code.google.com/p/mongoose/issues/detail?id=79
            memset(&de.file, 0, sizeof(de.file));
            mg_stat(conn, path, &de.file);
            if(de.file.modification_time) {
                if(de.file.is_directory) {
                    remove_directory(conn, path);
                } else {
                    remove(path);
                }
            }

        }
        (void) closedir(dirp);

        rmdir(dir);
    }

    return 1;
}

struct dir_scan_data {
    struct de *entries;
    int num_entries;
    int arr_size;
};

// Behaves like realloc(), but frees original pointer on failure
static void *realloc2(void *ptr, size_t size) {
    void *new_ptr = realloc(ptr, size);
    if(new_ptr == NULL) {
        free(ptr);
    }
    return new_ptr;
}

static void dir_scan_callback(struct de *de, void *data) {
    struct dir_scan_data *dsd = (struct dir_scan_data *) data;

    if(dsd->entries == NULL || dsd->num_entries >= dsd->arr_size) {
        dsd->arr_size *= 2;
        dsd->entries = (struct de *) realloc2(dsd->entries, dsd->arr_size *
                                                                                    sizeof(dsd->entries[0]));
    }
    if(dsd->entries == NULL) {
        // TODO(lsm): propagate an error to the caller
        dsd->num_entries = 0;
    } else {
        dsd->entries[dsd->num_entries].file_name = strdup(de->file_name);
        dsd->entries[dsd->num_entries].file = de->file;
        dsd->entries[dsd->num_entries].conn = de->conn;
        dsd->num_entries++;
    }
}

static void handle_directory_request(struct mg_connection *conn, const char *dir) {
    int i, sort_direction;
    struct dir_scan_data data = { NULL, 0, 128 };

    if(!scan_directory(conn, dir, &data, dir_scan_callback)) {
        send_http_error(conn, 500, "Cannot open directory",
                                        "Error: opendir(%s): %s", dir, strerror(errno));
        return;
    }

    sort_direction = conn->request_info.query_string != NULL &&
        conn->request_info.query_string[1] == 'd' ? 'a' : 'd';

    conn->must_close = 1;
    mg_printf(conn, "%s",
                        "HTTP/1.1 200 OK\r\n"
                        "Connection: close\r\n"
                        "Content-Type: text/html; charset=utf-8\r\n\r\n");

    conn->num_bytes_sent += mg_printf(conn,
            "<html><head><title>Index of %s</title>"
            "<style>th {text-align: left;}</style></head>"
            "<body><h1>Index of %s</h1><pre><table cellpadding=\"0\">"
            "<tr><th><a href=\"?n%c\">Name</a></th>"
            "<th><a href=\"?d%c\">Modified</a></th>"
            "<th><a href=\"?s%c\">Size</a></th></tr>"
            "<tr><td colspan=\"3\"><hr></td></tr>",
            conn->request_info.uri, conn->request_info.uri,
            sort_direction, sort_direction, sort_direction);

    // Print first entry - link to a parent directory
    conn->num_bytes_sent += mg_printf(conn,
            "<tr><td><a href=\"%s%s\">%s</a></td>"
            "<td>&nbsp;%s</td><td>&nbsp;&nbsp;%s</td></tr>\n",
            conn->request_info.uri, "..", "Parent directory", "-", "-");

    // Sort and print directory entries
    qsort(data.entries, (size_t) data.num_entries, sizeof(data.entries[0]),
                compare_dir_entries);
    for(i = 0; i < data.num_entries; i++) {
        print_dir_entry(&data.entries[i]);
        free(data.entries[i].file_name);
    }
    free(data.entries);

    conn->num_bytes_sent += mg_printf(conn, "%s", "</table></body></html>");
    conn->status_code = 200;
}

// Send len bytes from the opened file to the client.
static void send_file_data(struct mg_connection *conn, struct file *filep,
                           int64_t offset, int64_t len) {
    char buf[MG_BUF_LEN];
    int to_read, num_read, num_written;

    // Sanity check the offset
    offset = offset < 0 ? 0 : offset > filep->size ? filep->size : offset;

    if(len > 0 && filep->membuf != NULL && filep->size > 0) {
        if(len > filep->size - offset) {
            len = filep->size - offset;
        }
        mg_write(conn, filep->membuf + offset, (size_t) len);
    } else if(len > 0 && filep->fp != NULL) {
        fseeko(filep->fp, offset, SEEK_SET);
        while(len > 0) {
            // Calculate how much to read from the file in the buffer
            to_read = sizeof(buf);
            if((int64_t) to_read > len) {
                to_read = (int) len;
            }

            // Read from file, exit the loop on error
            if((num_read = fread(buf, 1, (size_t) to_read, filep->fp)) <= 0) {
                break;
            }

            // Send read bytes to the client, exit the loop on error
            if((num_written = mg_write(conn, buf, (size_t) num_read)) != num_read) {
                break;
            }

            // Both read and were successful, adjust counters
            conn->num_bytes_sent += num_written;
            len -= num_written;
        }
    }
}

static int parse_range_header(const char *header, int64_t *a, int64_t *b) {
    return sscanf(header, "bytes=%" INT64_FMT "-%" INT64_FMT, a, b);
}

static void gmt_time_string(char *buf, size_t buf_len, time_t *t) {
    strftime(buf, buf_len, "%a, %d %b %Y %H:%M:%S GMT", gmtime(t));
}

static void construct_etag(char *buf, size_t buf_len,
                           const struct file *filep) {
    snprintf(buf, buf_len, "\"%lx.%" INT64_FMT "\"",
                     (unsigned long) filep->modification_time, filep->size);
}

static void fclose_on_exec(struct file *filep) {
    if(filep != NULL && filep->fp != NULL) {
        fcntl(fileno(filep->fp), F_SETFD, FD_CLOEXEC);
    }
}

static void handle_file_request(struct mg_connection *conn, const char *path,
                                struct file *filep) {
    char date[64], lm[64], etag[64], range[64];
    const char *msg = "OK", *hdr;
    time_t curtime = time(NULL);
    int64_t cl, r1, r2;
    struct vec mime_vec;
    int n;
    char gz_path[PATH_MAX];
    char const* encoding = "";

    get_mime_type(conn->ctx, path, &mime_vec);
    cl = filep->size;
    conn->status_code = 200;
    range[0] = '\0';

    // if this file is in fact a pre-gzipped file, rewrite its filename
    // it's important to rewrite the filename after resolving
    // the mime type from it, to preserve the actual file's type
    if(filep->gzipped) {
        snprintf(gz_path, sizeof(gz_path), "%s.gz", path);
        path = gz_path;
        encoding = "Content-Encoding: gzip\r\n";
    }

    if(!mg_fopen(conn, path, "rb", filep)) {
        send_http_error(conn, 500, http_500_error,
                                        "fopen(%s): %s", path, strerror(errno));
        return;
    }

    fclose_on_exec(filep);

    // If Range: header specified, act accordingly
    r1 = r2 = 0;
    hdr = mg_get_header(conn, "Range");
    if(hdr != NULL && (n = parse_range_header(hdr, &r1, &r2)) > 0 &&
            r1 >= 0 && r2 >= 0) {
        // actually, range requests don't play well with a pre-gzipped
        // file (since the range is specified in the uncmpressed space)
        if(filep->gzipped) {
            send_http_error(conn, 501, "Not Implemented", "range requests in gzipped files are not supported");
            return;
        }
        conn->status_code = 206;
        cl = n == 2 ? (r2 > cl ? cl : r2) - r1 + 1: cl - r1;
        mg_snprintf(conn, range, sizeof(range),
                                "Content-Range: bytes "
                                "%" INT64_FMT "-%"
                                INT64_FMT "/%" INT64_FMT "\r\n",
                                r1, r1 + cl - 1, filep->size);
        msg = "Partial Content";
    }

    // Prepare Etag, Date, Last-Modified headers. Must be in UTC, according to
    // http://www.w3.org/Protocols/rfc2616/rfc2616-sec3.html#sec3.3
    gmt_time_string(date, sizeof(date), &curtime);
    gmt_time_string(lm, sizeof(lm), &filep->modification_time);
    construct_etag(etag, sizeof(etag), filep);

    (void) mg_printf(conn,
            "HTTP/1.1 %d %s\r\n"
            "Date: %s\r\n"
            "Last-Modified: %s\r\n"
            "Etag: %s\r\n"
            "Content-Type: %.*s\r\n"
            "Content-Length: %" INT64_FMT "\r\n"
            "Connection: %s\r\n"
            "Accept-Ranges: bytes\r\n"
            "%s%s\r\n",
            conn->status_code, msg, date, lm, etag, (int) mime_vec.len,
            mime_vec.ptr, cl, suggest_connection_header(conn), range, encoding);

    if(strcmp(conn->request_info.request_method, "HEAD") != 0) {
        send_file_data(conn, filep, r1, cl);
    }
    mg_fclose(filep);
}

void mg_send_file(struct mg_connection *conn, const char *path) {
    struct file file = STRUCT_FILE_INITIALIZER;
    if(mg_stat(conn, path, &file)) {
        handle_file_request(conn, path, &file);
    } else {
        send_http_error(conn, 404, "Not Found", "%s", "File not found");
    }
}


// Parse HTTP headers from the given buffer, advance buffer to the point
// where parsing stopped.
static void parse_http_headers(char **buf, struct mg_request_info *ri) {
    int i;

    for(i = 0; i < (int) ARRAY_SIZE(ri->http_headers); i++) {
        ri->http_headers[i].name = skip_quoted(buf, ":", " ", 0);
        ri->http_headers[i].value = skip(buf, "\r\n");
        if(ri->http_headers[i].name[0] == '\0')
            break;
        ri->num_headers = i + 1;
    }
}

static int is_valid_http_method(const char *method) {
    return !strcmp(method, "GET") || !strcmp(method, "POST") ||
        !strcmp(method, "HEAD") || !strcmp(method, "CONNECT") ||
        !strcmp(method, "PUT") || !strcmp(method, "DELETE") ||
        !strcmp(method, "OPTIONS") || !strcmp(method, "PROPFIND")
        || !strcmp(method, "MKCOL")
                    ;
}

// Parse HTTP request, fill in mg_request_info structure.
// This function modifies the buffer by NUL-terminating
// HTTP request components, header names and header values.
static int parse_http_message(char *buf, int len, struct mg_request_info *ri) {
    int is_request, request_length = get_request_len(buf, len);
    if(request_length > 0) {
        // Reset attributes. DO NOT TOUCH is_ssl, remote_ip, remote_port
        ri->remote_user = ri->request_method = ri->uri = ri->http_version = NULL;
        ri->num_headers = 0;

        buf[request_length - 1] = '\0';

        // RFC says that all initial whitespaces should be ingored
        while(*buf != '\0' && isspace(* (unsigned char *) buf)) {
            buf++;
        }
        ri->request_method = skip(&buf, " ");
        ri->uri = skip(&buf, " ");
        ri->http_version = skip(&buf, "\r\n");

        // HTTP message could be either HTTP request or HTTP response, e.g.
        // "GET / HTTP/1.0 ...." or    "HTTP/1.0 200 OK ..."
        is_request = is_valid_http_method(ri->request_method);
        if((is_request && memcmp(ri->http_version, "HTTP/", 5) != 0) ||
                (!is_request && memcmp(ri->request_method, "HTTP/", 5) != 0)) {
            request_length = -1;
        } else {
            if(is_request) {
                ri->http_version += 5;
            }
            parse_http_headers(&buf, ri);
        }
    }
    return request_length;
}

// Keep reading the input (either opened file descriptor fd, or socket sock,
// or SSL descriptor ssl) into buffer buf, until \r\n\r\n appears in the
// buffer (which marks the end of HTTP request). Buffer buf may already
// have some data. The length of the data is stored in nread.
// Upon every read operation, increase nread by the number of bytes read.
static int read_request(FILE *fp, struct mg_connection *conn,
                        char *buf, int bufsiz, int *nread) {
    int request_len, n = 0;

    request_len = get_request_len(buf, *nread);
    while(conn->ctx->stop_flag == 0 &&
                 *nread < bufsiz && request_len == 0 &&
                 (n = pull(fp, conn, buf + *nread, bufsiz - *nread)) > 0) {
        *nread += n;
        assert(*nread <= bufsiz);
        request_len = get_request_len(buf, *nread);
    }

    return request_len <= 0 && n <= 0 ? -1 : request_len;
}

// For given directory path, substitute it to valid index file.
// Return 0 if index file has been found, -1 if not found.
// If the file is found, it's stats is returned in stp.
static int substitute_index_file(struct mg_connection *conn, char *path,
                                 size_t path_len, struct file *filep) {
    const char *list = conn->ctx->config[INDEX_FILES];
    struct file file = STRUCT_FILE_INITIALIZER;
    struct vec filename_vec;
    size_t n = strlen(path);
    int found = 0;

    // The 'path' given to us points to the directory. Remove all trailing
    // directory separator characters from the end of the path, and
    // then append single directory separator character.
    while(n > 0 && path[n - 1] == '/') {
        n--;
    }
    path[n] = '/';

    // Traverse index files list. For each entry, append it to the given
    // path and see if the file exists. If it exists, break the loop
    while((list = next_option(list, &filename_vec, NULL)) != NULL) {

        // Ignore too long entries that may overflow path buffer
        if(filename_vec.len > path_len - (n + 2))
            continue;

        // Prepare full path to the index file
        mg_strlcpy(path + n + 1, filename_vec.ptr, filename_vec.len + 1);

        // Does it exist?
        if(mg_stat(conn, path, &file)) {
            // Yes it does, break the loop
            *filep = file;
            found = 1;
            break;
        }
    }

    // If no index file exists, restore directory path
    if(!found) {
        path[n] = '\0';
    }

    return found;
}

// Return True if we should reply 304 Not Modified.
static int is_not_modified(const struct mg_connection *conn,
                           const struct file *filep) {
    char etag[64];
    const char *ims = mg_get_header(conn, "If-Modified-Since");
    const char *inm = mg_get_header(conn, "If-None-Match");
    construct_etag(etag, sizeof(etag), filep);
    return (inm != NULL && !strcasecmp(etag, inm)) ||
        (ims != NULL && filep->modification_time <= parse_date_string(ims));
}

static int forward_body_data(struct mg_connection *conn, FILE *fp,
                             SOCKET sock, SSL *ssl) {
    const char *expect, *body;
    char buf[MG_BUF_LEN];
    int to_read, nread, buffered_len, success = 0;

    expect = mg_get_header(conn, "Expect");
    assert(fp != NULL);

    if(conn->content_len == -1) {
        send_http_error(conn, 411, "Length Required", "%s", "");
    } else if(expect != NULL && strcasecmp(expect, "100-continue")) {
        send_http_error(conn, 417, "Expectation Failed", "%s", "");
    } else {
        if(expect != NULL) {
            (void) mg_printf(conn, "%s", "HTTP/1.1 100 Continue\r\n\r\n");
        }

        body = conn->buf + conn->request_len + conn->consumed_content;
        buffered_len = &conn->buf[conn->data_len] - body;
        assert(buffered_len >= 0);
        assert(conn->consumed_content == 0);

        if(buffered_len > 0) {
            if((int64_t) buffered_len > conn->content_len) {
                buffered_len = (int) conn->content_len;
            }
            push(fp, sock, ssl, body, (int64_t) buffered_len);
            conn->consumed_content += buffered_len;
        }

        nread = 0;
        while(conn->consumed_content < conn->content_len) {
            to_read = sizeof(buf);
            if((int64_t) to_read > conn->content_len - conn->consumed_content) {
                to_read = (int) (conn->content_len - conn->consumed_content);
            }
            nread = pull(NULL, conn, buf, to_read);
            if(nread <= 0 || push(fp, sock, ssl, buf, nread) != nread) {
                break;
            }
            conn->consumed_content += nread;
        }

        if(conn->consumed_content == conn->content_len) {
            success = nread >= 0;
        }

        // Each error code path in this function must send an error
        if(!success) {
            send_http_error(conn, 577, http_500_error, "%s", "");
        }
    }

    return success;
}

// For a given PUT path, create all intermediate subdirectories
// for given path. Return 0 if the path itself is a directory,
// or -1 on error, 1 if OK.
static int put_dir(struct mg_connection *conn, const char *path) {
    char buf[PATH_MAX];
    const char *s, *p;
    struct file file = STRUCT_FILE_INITIALIZER;
    int len, res = 1;

    for(s = p = path + 2; (p = strchr(s, '/')) != NULL; s = ++p) {
        len = p - path;
        if(len >= (int) sizeof(buf)) {
            res = -1;
            break;
        }
        memcpy(buf, path, len);
        buf[len] = '\0';

        // Try to create intermediate directory
        DEBUG_TRACE(("mkdir(%s)", buf));
        if(!mg_stat(conn, buf, &file) && mkdir(buf, 0755) != 0) {
            res = -1;
            break;
        }

        // Is path itself a directory?
        if(p[1] == '\0') {
            res = 0;
        }
    }

    return res;
}

static void mkcol(struct mg_connection *conn, const char *path) {
    int rc, body_len;
    struct de de;
    memset(&de.file, 0, sizeof(de.file));
    mg_stat(conn, path, &de.file);

    if(de.file.modification_time) {
            send_http_error(conn, 405, "Method Not Allowed",
                                            "mkcol(%s): %s", path, strerror(errno));
            return;
    }

    body_len = conn->data_len - conn->request_len;
    if(body_len > 0) {
            send_http_error(conn, 415, "Unsupported media type",
                                            "mkcol(%s): %s", path, strerror(errno));
            return;
    }

    rc = mkdir(path, 0755);

    if(rc == 0) {
        conn->status_code = 201;
        mg_printf(conn, "HTTP/1.1 %d Created\r\n\r\n", conn->status_code);
    } else if(rc == -1) {
            if(errno == EEXIST)
                send_http_error(conn, 405, "Method Not Allowed",
                                            "mkcol(%s): %s", path, strerror(errno));
            else if(errno == EACCES)
                    send_http_error(conn, 403, "Forbidden",
                                                "mkcol(%s): %s", path, strerror(errno));
            else if(errno == ENOENT)
                    send_http_error(conn, 409, "Conflict",
                                                "mkcol(%s): %s", path, strerror(errno));
            else
                    send_http_error(conn, 500, http_500_error,
                                                    "fopen(%s): %s", path, strerror(errno));
    }
}

static void put_file(struct mg_connection *conn, const char *path) {
    struct file file = STRUCT_FILE_INITIALIZER;
    const char *range;
    int64_t r1, r2;
    int rc;

    conn->status_code = mg_stat(conn, path, &file) ? 200 : 201;

    if((rc = put_dir(conn, path)) == 0) {
        mg_printf(conn, "HTTP/1.1 %d OK\r\n\r\n", conn->status_code);
    } else if(rc == -1) {
        send_http_error(conn, 500, http_500_error,
                                        "put_dir(%s): %s", path, strerror(errno));
    } else if(!mg_fopen(conn, path, "wb+", &file) || file.fp == NULL) {
        mg_fclose(&file);
        send_http_error(conn, 500, http_500_error,
                                        "fopen(%s): %s", path, strerror(errno));
    } else {
        fclose_on_exec(&file);
        range = mg_get_header(conn, "Content-Range");
        r1 = r2 = 0;
        if(range != NULL && parse_range_header(range, &r1, &r2) > 0) {
            conn->status_code = 206;
            fseeko(file.fp, r1, SEEK_SET);
        }
        if(!forward_body_data(conn, file.fp, INVALID_SOCKET, NULL)) {
            conn->status_code = 500;
        }
        mg_printf(conn, "HTTP/1.1 %d OK\r\nContent-Length: 0\r\n\r\n",
                            conn->status_code);
        mg_fclose(&file);
    }
}

static void send_options(struct mg_connection *conn) {
    conn->status_code = 200;

    mg_printf(conn, "%s", "HTTP/1.1 200 OK\r\n"
                    "Allow: GET, POST, HEAD, CONNECT, PUT, DELETE, OPTIONS, PROPFIND, MKCOL\r\n"
                    "DAV: 1\r\n\r\n");
}

// Writes PROPFIND properties for a collection element
static void print_props(struct mg_connection *conn, const char* uri, struct file *filep) {
    char mtime[64];
    gmt_time_string(mtime, sizeof(mtime), &filep->modification_time);
    conn->num_bytes_sent += mg_printf(conn,
            "<d:response>"
             "<d:href>%s</d:href>"
             "<d:propstat>"
                "<d:prop>"
                 "<d:resourcetype>%s</d:resourcetype>"
                 "<d:getcontentlength>%" INT64_FMT "</d:getcontentlength>"
                 "<d:getlastmodified>%s</d:getlastmodified>"
                "</d:prop>"
                "<d:status>HTTP/1.1 200 OK</d:status>"
             "</d:propstat>"
            "</d:response>\n",
            uri,
            filep->is_directory ? "<d:collection/>" : "",
            filep->size,
            mtime);
}

static void print_dav_dir_entry(struct de *de, void *data) {
    char href[PATH_MAX];
    char href_encoded[PATH_MAX];
    struct mg_connection *conn = (struct mg_connection *) data;
    mg_snprintf(conn, href, sizeof(href), "%s%s",
                            conn->request_info.uri, de->file_name);
    mg_url_encode(href, href_encoded, PATH_MAX-1);
    print_props(conn, href_encoded, &de->file);
}

static void handle_propfind(struct mg_connection *conn, const char *path,
                            struct file *filep) {
    const char *depth = mg_get_header(conn, "Depth");

    conn->must_close = 1;
    conn->status_code = 207;
    mg_printf(conn, "HTTP/1.1 207 Multi-Status\r\n"
                    "Connection: close\r\n"
                    "Content-Type: text/xml; charset=utf-8\r\n\r\n");

    conn->num_bytes_sent += mg_printf(conn,
        "<?xml version=\"1.0\" encoding=\"utf-8\"?>"
        "<d:multistatus xmlns:d='DAV:'>\n");

    // Print properties for the requested resource itself
    print_props(conn, conn->request_info.uri, filep);

    // If it is a directory, print directory entries too if Depth is not 0
    if(filep->is_directory &&
            !strcasecmp(conn->ctx->config[ENABLE_DIRECTORY_LISTING], "yes") &&
            (depth == NULL || strcmp(depth, "0") != 0)) {
        scan_directory(conn, path, conn, &print_dav_dir_entry);
    }

    conn->num_bytes_sent += mg_printf(conn, "%s\n", "</d:multistatus>");
}

static void base64_encode(const unsigned char *src, int src_len, char *dst) {
    static const char *b64 =
        "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
    int i, j, a, b, c;

    for(i = j = 0; i < src_len; i += 3) {
        a = src[i];
        b = i + 1 >= src_len ? 0 : src[i + 1];
        c = i + 2 >= src_len ? 0 : src[i + 2];

        dst[j++] = b64[a >> 2];
        dst[j++] = b64[((a & 3) << 4) | (b >> 4)];
        if(i + 1 < src_len) {
            dst[j++] = b64[(b & 15) << 2 | (c >> 6)];
        }
        if(i + 2 < src_len) {
            dst[j++] = b64[c & 63];
        }
    }
    while(j % 4 != 0) {
        dst[j++] = '=';
    }
    dst[j++] = '\0';
}

static void send_websocket_handshake(struct mg_connection *conn) {
    static const char *magic = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11";
    char buf[100], sha[20], b64_sha[sizeof(sha) * 2];
    SHA_CTX sha_ctx;

    mg_snprintf(conn, buf, sizeof(buf), "%s%s",
                            mg_get_header(conn, "Sec-WebSocket-Key"), magic);
    SHA1_Init(&sha_ctx);
    SHA1_Update(&sha_ctx, (unsigned char *) buf, strlen(buf));
    SHA1_Final((unsigned char *) sha, &sha_ctx);
    base64_encode((unsigned char *) sha, sizeof(sha), b64_sha);
    mg_printf(conn, "%s%s%s",
                    "HTTP/1.1 101 Switching Protocols\r\n"
                    "Upgrade: websocket\r\n"
                    "Connection: Upgrade\r\n"
                    "Sec-WebSocket-Accept: ", b64_sha, "\r\n\r\n");
}

static void read_websocket(struct mg_connection *conn) {
    // Pointer to the beginning of the portion of the incoming websocket message
    // queue. The original websocket upgrade request is never removed,
    // so the queue begins after it.
    unsigned char *buf = (unsigned char *) conn->buf + conn->request_len;
    int bits, n, stop = 0;
    size_t i, len, mask_len, data_len, header_len, body_len;
    // data points to the place where the message is stored when passed to the
    // websocket_data callback. This is either mem on the stack,
    // or a dynamically allocated buffer if it is too large.
    char mem[4 * 1024], mask[4], *data;

    assert(conn->content_len == 0);

    // Loop continuously, reading messages from the socket, invoking the callback,
    // and waiting repeatedly until an error occurs.
    while(!stop) {
        header_len = 0;
        // body_len is the length of the entire queue in bytes
        // len is the length of the current message
        // data_len is the length of the current message's data payload
        // header_len is the length of the current message's header
        if((body_len = conn->data_len - conn->request_len) >= 2) {
            len = buf[1] & 127;
            mask_len = buf[1] & 128 ? 4 : 0;
            if(len < 126 && body_len >= mask_len) {
                data_len = len;
                header_len = 2 + mask_len;
            } else if(len == 126 && body_len >= 4 + mask_len) {
                header_len = 4 + mask_len;
                data_len = ((((int) buf[2]) << 8) + buf[3]);
            } else if(body_len >= 10 + mask_len) {
                header_len = 10 + mask_len;
                data_len = (((uint64_t) htonl(* (uint32_t *) &buf[2])) << 32) +
                    htonl(* (uint32_t *) &buf[6]);
            }
        }

        // Data layout is as follows:
        //    conn->buf                             buf
        //         v                                         v                            frame1                     | frame2
        //         |---------------------|----------------|--------------|-------
        //         |                                         |<--header_len-->|<--data_len-->|
        //         |<-conn->request_len->|<-----body_len----------->|
        //         |<-------------------conn->data_len------------->|

        if(header_len > 0) {
            // Allocate space to hold websocket payload
            data = mem;
            if(data_len > sizeof(mem) && (data = malloc(data_len)) == NULL) {
                // Allocation failed, exit the loop and then close the connection
                // TODO: notify user about the failure
                break;
            }

            // Save mask and bits, otherwise it may be clobbered by memmove below
            bits = buf[0];
            memcpy(mask, buf + header_len - mask_len, mask_len);

            // Read frame payload into the allocated buffer.
            assert(body_len >= header_len);
            if(data_len + header_len > body_len) {
                len = body_len - header_len;
                memcpy(data, buf + header_len, len);
                // TODO: handle pull error
                pull_all(NULL, conn, data + len, data_len - len);
                conn->data_len = conn->request_len;
            } else {
                len = data_len + header_len;
                memcpy(data, buf + header_len, data_len);
                memmove(buf, buf + len, body_len - len);
                conn->data_len -= len;
            }

            // Apply mask if necessary
            if(mask_len > 0) {
                for(i = 0; i < data_len; i++) {
                    data[i] ^= mask[i % 4];
                }
            }

            // Exit the loop if callback signalled to exit,
            // or "connection close" opcode received.
            if((bits & WEBSOCKET_OPCODE_CONNECTION_CLOSE) ||
               (conn->ctx->callbacks.websocket_data != NULL &&
                !conn->ctx->callbacks.websocket_data(conn, bits, data, data_len))) {
                stop = 1;
            }

            if(data != mem) {
                free(data);
            }
            // Not breaking the loop, process next websocket frame.
        } else {
            // Buffering websocket request
            if((n = pull(NULL, conn, conn->buf + conn->data_len,
                         conn->buf_size - conn->data_len)) <= 0) {
                break;
            }
            conn->data_len += n;
        }
    }
}

int mg_websocket_write(struct mg_connection* conn, int opcode,
                       const char *data, unsigned long data_len) {
        unsigned char *copy;
        size_t copy_len = 0;
        int retval = -1;

        if((copy = (unsigned char *) malloc(data_len + 10)) == NULL) {
            return -1;
        }

        copy[0] = 0x80 + (opcode & 0x0f);

        // Frame format: http://tools.ietf.org/html/rfc6455#section-5.2
        if(data_len < 126) {
            // Inline 7-bit length field
            copy[1] = data_len;
            memcpy(copy + 2, data, data_len);
            copy_len = 2 + data_len;
        } else if(data_len <= 0xFFFF) {
            // 16-bit length field
            copy[1] = 126;
            * (uint16_t *) (copy + 2) = htons(data_len);
            memcpy(copy + 4, data, data_len);
            copy_len = 4 + data_len;
        } else {
            // 64-bit length field
            copy[1] = 127;
            * (uint32_t *) (copy + 2) = htonl((uint64_t) data_len >> 32);
            * (uint32_t *) (copy + 6) = htonl(data_len & 0xffffffff);
            memcpy(copy + 10, data, data_len);
            copy_len = 10 + data_len;
        }

        // Not thread safe
        if(copy_len > 0) {
            retval = mg_write(conn, copy, copy_len);
        }
        free(copy);

        return retval;
}

static void handle_websocket_request(struct mg_connection *conn) {
    const char *version = mg_get_header(conn, "Sec-WebSocket-Version");
    if(version == NULL || strcmp(version, "13") != 0) {
        send_http_error(conn, 426, "Upgrade Required", "%s", "Upgrade Required");
    } else if(conn->ctx->callbacks.websocket_connect != NULL &&
              conn->ctx->callbacks.websocket_connect(conn) != 0) {
        // Callback has returned non-zero, do not proceed with handshake
    } else {
        send_websocket_handshake(conn);
        if(conn->ctx->callbacks.websocket_ready != NULL) {
            conn->ctx->callbacks.websocket_ready(conn);
        }
        read_websocket(conn);
    }
}

static int is_websocket_request(const struct mg_connection *conn) {
    const char *host, *upgrade, *connection, *version, *key;

    host = mg_get_header(conn, "Host");
    upgrade = mg_get_header(conn, "Upgrade");
    connection = mg_get_header(conn, "Connection");
    key = mg_get_header(conn, "Sec-WebSocket-Key");
    version = mg_get_header(conn, "Sec-WebSocket-Version");

    return host != NULL && upgrade != NULL && connection != NULL &&
        key != NULL && version != NULL &&
        strcasestr(upgrade, "websocket") != NULL &&
        strcasestr(connection, "Upgrade") != NULL;
}

static int isbyte(int n) {
    return n >= 0 && n <= 255;
}

static int parse_net(const char *spec, uint32_t *net, uint32_t *mask) {
    int n, a, b, c, d, slash = 32, len = 0;

    if((sscanf(spec, "%d.%d.%d.%d/%d%n", &a, &b, &c, &d, &slash, &n) == 5 ||
        sscanf(spec, "%d.%d.%d.%d%n", &a, &b, &c, &d, &n) == 4) &&
        isbyte(a) && isbyte(b) && isbyte(c) && isbyte(d) &&
        slash >= 0 && slash < 33) {
        len = n;
        *net = ((uint32_t)a << 24) | ((uint32_t)b << 16) | ((uint32_t)c << 8) | d;
        *mask = slash ? 0xffffffffU << (32 - slash) : 0;
    }

    return len;
}

static int set_throttle(const char *spec, uint32_t remote_ip, const char *uri) {
    int throttle = 0;
    struct vec vec, val;
    uint32_t net, mask;
    char mult;
    double v;

    while((spec = next_option(spec, &vec, &val)) != NULL) {
        mult = ',';
        if(sscanf(val.ptr, "%lf%c", &v, &mult) < 1 || v < 0 ||
                (lowercase(&mult) != 'k' && lowercase(&mult) != 'm' && mult != ',')) {
            continue;
        }
        v *= lowercase(&mult) == 'k' ? 1024 : lowercase(&mult) == 'm' ? 1048576 : 1;
        if(vec.len == 1 && vec.ptr[0] == '*') {
            throttle = (int) v;
        } else if(parse_net(vec.ptr, &net, &mask) > 0) {
            if((remote_ip & mask) == net) {
                throttle = (int) v;
            }
        } else if(match_prefix(vec.ptr, vec.len, uri) > 0) {
            throttle = (int) v;
        }
    }

    return throttle;
}

static uint32_t get_remote_ip(const struct mg_connection *conn) {
    return ntohl(* (uint32_t *) &conn->client.rsa.sin.sin_addr);
}

static int is_put_or_delete_request(const struct mg_connection *conn) {
    const char *s = conn->request_info.request_method;
    return s != NULL && (!strcmp(s, "PUT")    ||
                         !strcmp(s, "DELETE") ||
                         !strcmp(s, "MKCOL"));
}

static int get_first_ssl_listener_index(const struct mg_context *ctx) {
    int i, index = -1;
    for(i = 0; index == -1 && i < ctx->num_listening_sockets; i++) {
        index = ctx->listening_sockets[i].is_ssl ? i : -1;
    }
    return index;
}

static void redirect_to_https_port(struct mg_connection *conn, int ssl_index) {
    char host[1025];
    const char *host_header;

    if((host_header = mg_get_header(conn, "Host")) == NULL ||
        sscanf(host_header, "%1024[^:]", host) == 0) {
        // Cannot get host from the Host: header. Fallback to our IP address.
        sockaddr_to_string(host, sizeof(host), &conn->client.lsa);
    }

    mg_printf(conn, "HTTP/1.1 302 Found\r\nLocation: https://%s:%d%s\r\n\r\n",
                    host, (int) ntohs(conn->ctx->listening_sockets[ssl_index].
                                      lsa.sin.sin_port), conn->request_info.uri);
}

// This is the heart of the Mongoose's logic.
// This function is called when the request is read, parsed and validated,
// and Mongoose must decide what action to take: serve a file, or
// a directory, or call embedded function, etcetera.
static void handle_request(struct mg_connection *conn) {
    struct mg_request_info *ri = &conn->request_info;
    char path[PATH_MAX];
    int uri_len, ssl_index;
    struct file file = STRUCT_FILE_INITIALIZER;

    if((conn->request_info.query_string = strchr(ri->uri, '?')) != NULL) {
        * ((char *) conn->request_info.query_string++) = '\0';
    }
    uri_len = (int) strlen(ri->uri);
    mg_url_decode(ri->uri, uri_len, (char *) ri->uri, uri_len + 1, 0);
    remove_double_dots_and_double_slashes((char *) ri->uri);
    convert_uri_to_file_name(conn, path, sizeof(path), &file);
    conn->throttle = set_throttle(conn->ctx->config[THROTTLE],
                                  get_remote_ip(conn), ri->uri);

    DEBUG_TRACE(("%s", ri->uri));
    // Perform redirect and auth checks before calling begin_request() handler.
    // Otherwise, begin_request() would need to perform auth checks and redirects.
    if(!conn->client.is_ssl && conn->client.ssl_redir &&
        (ssl_index = get_first_ssl_listener_index(conn->ctx)) > -1) {
        redirect_to_https_port(conn, ssl_index);
    } else if(!is_put_or_delete_request(conn) &&
                         !check_authorization(conn, path)) {
        send_authorization_request(conn);
    } else if(conn->ctx->callbacks.begin_request != NULL &&
            conn->ctx->callbacks.begin_request(conn)) {
        // Do nothing, callback has served the request
    } else if(is_websocket_request(conn)) {
        handle_websocket_request(conn);
    } else if(!strcmp(ri->request_method, "OPTIONS")) {
        send_options(conn);
    } else if(conn->ctx->config[DOCUMENT_ROOT] == NULL) {
        send_http_error(conn, 404, "Not Found", "Not Found");
    } else if(is_put_or_delete_request(conn) &&
               (is_authorized_for_put(conn) != 1)) {
        send_authorization_request(conn);
    } else if(!strcmp(ri->request_method, "PUT")) {
        put_file(conn, path);
    } else if(!strcmp(ri->request_method, "MKCOL")) {
        mkcol(conn, path);
    } else if(!strcmp(ri->request_method, "DELETE")) {
        struct de de;
        memset(&de.file, 0, sizeof(de.file));
        if(!mg_stat(conn, path, &de.file)) {
            send_http_error(conn, 404, "Not Found", "%s", "File not found");
        } else {
            if(de.file.modification_time) {
                if(de.file.is_directory) {
                    remove_directory(conn, path);
                    send_http_error(conn, 204, "No Content", "%s", "");
                } else if(remove(path) == 0) {
                    send_http_error(conn, 204, "No Content", "%s", "");
                } else {
                    send_http_error(conn, 423, "Locked", "remove(%s): %s", path,
                                    strerror(errno));
                }
            }
            else {
                send_http_error(conn, 500, http_500_error, "remove(%s): %s", path,
                                strerror(errno));
            }
        }
    } else if((file.membuf == NULL && file.modification_time == (time_t) 0) ||
                         must_hide_file(conn, path)) {
        send_http_error(conn, 404, "Not Found", "%s", "File not found");
    } else if(file.is_directory && ri->uri[uri_len - 1] != '/') {
        mg_printf(conn, "HTTP/1.1 301 Moved Permanently\r\n"
                            "Location: %s/\r\n\r\n", ri->uri);
    } else if(!strcmp(ri->request_method, "PROPFIND")) {
        handle_propfind(conn, path, &file);
    } else if(file.is_directory &&
                         !substitute_index_file(conn, path, sizeof(path), &file)) {
        if(!strcasecmp(conn->ctx->config[ENABLE_DIRECTORY_LISTING], "yes")) {
            handle_directory_request(conn, path);
        } else {
            send_http_error(conn, 403, "Directory Listing Denied",
                    "Directory listing denied");
        }
    } else if(is_not_modified(conn, &file)) {
        send_http_error(conn, 304, "Not Modified", "%s", "");
    } else {
        handle_file_request(conn, path, &file);
    }
}

static void close_all_listening_sockets(struct mg_context *ctx) {
    int i;
    for(i = 0; i < ctx->num_listening_sockets; i++) {
        closesocket(ctx->listening_sockets[i].sock);
    }
    free(ctx->listening_sockets);
}

static int is_valid_port(unsigned int port) {
    return port > 0 && port < 0xffff;
}

// Valid listening port specification is: [ip_address:]port[s]
// Examples: 80, 443s, 127.0.0.1:3128, 1.2.3.4:8080s
// TODO(lsm): add parsing of the IPv6 address
static int parse_port_string(const struct vec *vec, struct socket *so) {
    unsigned int a, b, c, d, ch, len, port;
#if defined(USE_IPV6)
    char buf[100];
#endif

    // MacOS needs that. If we do not zero it, subsequent bind() will fail.
    // Also, all-zeroes in the socket address means binding to all addresses
    // for both IPv4 and IPv6 (INADDR_ANY and IN6ADDR_ANY_INIT).
    memset(so, 0, sizeof(*so));
    so->lsa.sin.sin_family = AF_INET;

    if(sscanf(vec->ptr, "%u.%u.%u.%u:%u%n", &a, &b, &c, &d, &port, &len) == 5) {
        // Bind to a specific IPv4 address, e.g. 192.168.1.5:8080
        so->lsa.sin.sin_addr.s_addr = htonl((a << 24) | (b << 16) | (c << 8) | d);
        so->lsa.sin.sin_port = htons((uint16_t) port);
#if defined(USE_IPV6)

    } else if(sscanf(vec->ptr, "[%49[^]]]:%d%n", buf, &port, &len) == 2 &&
                         inet_pton(AF_INET6, buf, &so->lsa.sin6.sin6_addr)) {
        // IPv6 address, e.g. [3ffe:2a00:100:7031::1]:8080
        so->lsa.sin6.sin6_family = AF_INET6;
        so->lsa.sin6.sin6_port = htons((uint16_t) port);
#endif
    } else if(sscanf(vec->ptr, "%u%n", &port, &len) == 1) {
        // If only port is specified, bind to IPv4, INADDR_ANY
        so->lsa.sin.sin_port = htons((uint16_t) port);
    } else {
        port = len = 0;     // Parsing failure. Make port invalid.
    }

    ch = vec->ptr[len];    // Next character after the port number
    so->is_ssl = ch == 's';
    so->ssl_redir = ch == 'r';

    // Make sure the port is valid and vector ends with 's', 'r' or ','
    return is_valid_port(port) &&
        (ch == '\0' || ch == 's' || ch == 'r' || ch == ',');
}

static int set_ports_option(struct mg_context *ctx) {
    const char *list = ctx->config[LISTENING_PORTS];
    int on = 1, success = 1;
#if defined(USE_IPV6)
    int off = 0;
#endif
    struct vec vec;
    struct socket so, *ptr;

    while(success && (list = next_option(list, &vec, NULL)) != NULL) {
        if(!parse_port_string(&vec, &so)) {
            cry(fc(ctx), "%s: %.*s: invalid port spec. Expecting list of: %s",
                    __func__, (int) vec.len, vec.ptr, "[IP_ADDRESS:]PORT[s|r]");
            success = 0;
        } else if(so.is_ssl && ctx->ssl_ctx == NULL) {
            cry(fc(ctx), "Cannot add SSL socket, is -ssl_certificate option set?");
            success = 0;
        } else if((so.sock = socket(so.lsa.sa.sa_family, SOCK_STREAM, 6)) ==
                             INVALID_SOCKET ||
                             // On Windows, SO_REUSEADDR is recommended only for
                             // broadcast UDP sockets
                             setsockopt(so.sock, SOL_SOCKET, SO_REUSEADDR,
                                                    (void *) &on, sizeof(on)) != 0 ||
#if defined(USE_IPV6)
                             (so.lsa.sa.sa_family == AF_INET6 &&
                                setsockopt(so.sock, IPPROTO_IPV6, IPV6_V6ONLY, (void *) &off,
                                                     sizeof(off)) != 0) ||
#endif
                             bind(so.sock, &so.lsa.sa, so.lsa.sa.sa_family == AF_INET ?
                                        sizeof(so.lsa.sin) : sizeof(so.lsa)) != 0 ||
                             listen(so.sock, SOMAXCONN) != 0) {
            cry(fc(ctx), "%s: cannot bind to %.*s: %d (%s)", __func__,
                    (int) vec.len, vec.ptr, errno, strerror(errno));
            closesocket(so.sock);
            success = 0;
        } else if((ptr = (struct socket *) realloc(ctx->listening_sockets,
                                                            (ctx->num_listening_sockets + 1) *
                                                            sizeof(ctx->listening_sockets[0]))) == NULL) {
            closesocket(so.sock);
            success = 0;
        } else {
            set_close_on_exec(so.sock);
            ctx->listening_sockets = ptr;
            ctx->listening_sockets[ctx->num_listening_sockets] = so;
            ctx->num_listening_sockets++;
        }
    }

    if(!success) {
        close_all_listening_sockets(ctx);
    }

    return success;
}

static void log_header(const struct mg_connection *conn, const char *header, FILE *fp) {
    const char *header_value;

    if((header_value = mg_get_header(conn, header)) == NULL) {
        (void) fprintf(fp, "%s", " -");
    } else {
        (void) fprintf(fp, " \"%s\"", header_value);
    }
}

static void log_access(const struct mg_connection *conn) {
    const struct mg_request_info *ri;
    FILE *fp;
    char date[64], src_addr[IP_ADDR_STR_LEN];

    fp = conn->ctx->config[ACCESS_LOG_FILE] == NULL ?    NULL :
        fopen(conn->ctx->config[ACCESS_LOG_FILE], "a+");

    if(fp == NULL)
        return;

    strftime(date, sizeof(date), "%d/%b/%Y:%H:%M:%S %z",
                     localtime(&conn->birth_time));

    ri = &conn->request_info;
    flockfile(fp);

    sockaddr_to_string(src_addr, sizeof(src_addr), &conn->client.rsa);
    fprintf(fp, "%s - %s [%s] \"%s %s HTTP/%s\" %d %" INT64_FMT,
                    src_addr, ri->remote_user == NULL ? "-" : ri->remote_user, date,
                    ri->request_method ? ri->request_method : "-",
                    ri->uri ? ri->uri : "-", ri->http_version,
                    conn->status_code, conn->num_bytes_sent);
    log_header(conn, "Referer", fp);
    log_header(conn, "User-Agent", fp);
    fputc('\n', fp);
    fflush(fp);

    funlockfile(fp);
    fclose(fp);
}

// Verify given socket address against the ACL.
// Return -1 if ACL is malformed, 0 if address is disallowed, 1 if allowed.
static int check_acl(struct mg_context *ctx, uint32_t remote_ip) {
    int allowed, flag;
    uint32_t net, mask;
    struct vec vec;
    const char *list = ctx->config[ACCESS_CONTROL_LIST];

    // If any ACL is set, deny by default
    allowed = list == NULL ? '+' : '-';

    while((list = next_option(list, &vec, NULL)) != NULL) {
        flag = vec.ptr[0];
        if((flag != '+' && flag != '-') ||
                parse_net(&vec.ptr[1], &net, &mask) == 0) {
            cry(fc(ctx), "%s: subnet must be [+|-]x.x.x.x[/x]", __func__);
            return -1;
        }

        if(net == (remote_ip & mask)) {
            allowed = flag;
        }
    }

    return allowed == '+';
}

static int set_uid_option(struct mg_context *ctx) {
    struct passwd *pw;
    const char *uid = ctx->config[RUN_AS_USER];
    int success = 0;

    if(uid == NULL) {
        success = 1;
    } else {
        if((pw = getpwnam(uid)) == NULL) {
            cry(fc(ctx), "%s: unknown user [%s]", __func__, uid);
        } else if(setgid(pw->pw_gid) == -1) {
            cry(fc(ctx), "%s: setgid(%s): %s", __func__, uid, strerror(errno));
        } else if(setuid(pw->pw_uid) == -1) {
            cry(fc(ctx), "%s: setuid(%s): %s", __func__, uid, strerror(errno));
        } else {
            success = 1;
        }
    }

    return success;
}

static pthread_mutex_t *ssl_mutexes;

static int sslize(struct mg_connection *conn, SSL_CTX *s, int (*func)(SSL *)) {
    return (conn->ssl = SSL_new(s)) != NULL &&
        SSL_set_fd(conn->ssl, conn->client.sock) == 1 &&
        func(conn->ssl) == 1;
}

// Return OpenSSL error message
static const char *ssl_error(void) {
    unsigned long err;
    err = ERR_get_error();
    return err == 0 ? "" : ERR_error_string(err, NULL);
}

static void ssl_locking_callback(int mode, int mutex_num, const char *file,
                                                                 int line) {
    (void) line;
    (void) file;

    if(mode & 1) {    // 1 is CRYPTO_LOCK
        (void) pthread_mutex_lock(&ssl_mutexes[mutex_num]);
    } else {
        (void) pthread_mutex_unlock(&ssl_mutexes[mutex_num]);
    }
}

static unsigned long ssl_id_callback(void) {
    return (unsigned long) pthread_self();
}

// Dynamically load SSL library. Set up ctx->ssl_ctx pointer.
static int set_ssl_option(struct mg_context *ctx) {
    int i, size;
    const char *pem;

    // If PEM file is not specified and the init_ssl callback
    // is not specified, skip SSL initialization.
    if((pem = ctx->config[SSL_CERTIFICATE]) == NULL &&
            ctx->callbacks.init_ssl == NULL) {
        return 1;
    }

    // Initialize SSL library
    SSL_library_init();
    SSL_load_error_strings();

    if((ctx->ssl_ctx = SSL_CTX_new(SSLv23_server_method())) == NULL) {
        cry(fc(ctx), "SSL_CTX_new (server) error: %s", ssl_error());
        return 0;
    }

    // If user callback returned non-NULL, that means that user callback has
    // set up certificate itself. In this case, skip sertificate setting.
    if((ctx->callbacks.init_ssl == NULL ||
             !ctx->callbacks.init_ssl(ctx->ssl_ctx, ctx->user_data)) &&
            (SSL_CTX_use_certificate_file(ctx->ssl_ctx, pem, 1) == 0 ||
             SSL_CTX_use_PrivateKey_file(ctx->ssl_ctx, pem, 1) == 0)) {
        cry(fc(ctx), "%s: cannot open %s: %s", __func__, pem, ssl_error());
        return 0;
    }

    if(pem != NULL) {
        (void) SSL_CTX_use_certificate_chain_file(ctx->ssl_ctx, pem);
    }

    // Initialize locking callbacks, needed for thread safety.
    // http://www.openssl.org/support/faq.html#PROG1
    size = sizeof(pthread_mutex_t) * CRYPTO_num_locks();
    if((ssl_mutexes = (pthread_mutex_t *) malloc((size_t)size)) == NULL) {
        cry(fc(ctx), "%s: cannot allocate mutexes: %s", __func__, ssl_error());
        return 0;
    }

    for(i = 0; i < CRYPTO_num_locks(); i++) {
        pthread_mutex_init(&ssl_mutexes[i], NULL);
    }

    CRYPTO_set_locking_callback(&ssl_locking_callback);
    CRYPTO_set_id_callback(&ssl_id_callback);

    return 1;
}

static void uninitialize_ssl(struct mg_context *ctx) {
    int i;
    if(ctx->ssl_ctx != NULL) {
        CRYPTO_set_locking_callback(NULL);
        for(i = 0; i < CRYPTO_num_locks(); i++) {
            pthread_mutex_destroy(&ssl_mutexes[i]);
        }
        CRYPTO_set_locking_callback(NULL);
        CRYPTO_set_id_callback(NULL);
    }
}

static int set_gpass_option(struct mg_context *ctx) {
    struct file file = STRUCT_FILE_INITIALIZER;
    const char *path = ctx->config[GLOBAL_PASSWORDS_FILE];
    if(path != NULL && !mg_stat(fc(ctx), path, &file)) {
        cry(fc(ctx), "Cannot open %s: %s", path, strerror(errno));
        return 0;
    }
    return 1;
}

static int set_acl_option(struct mg_context *ctx) {
    return check_acl(ctx, (uint32_t) 0x7f000001UL) != -1;
}

static void reset_per_request_attributes(struct mg_connection *conn) {
    conn->path_info = NULL;
    conn->num_bytes_sent = conn->consumed_content = 0;
    conn->status_code = -1;
    conn->must_close = conn->request_len = conn->throttle = 0;
}

static void close_socket_gracefully(struct mg_connection *conn) {
    struct linger linger;

    // Set linger option to avoid socket hanging out after close. This prevent
    // ephemeral port exhaust problem under high QPS.
    linger.l_onoff = 1;
    linger.l_linger = 1;
    setsockopt(conn->client.sock, SOL_SOCKET, SO_LINGER,
                         (char *) &linger, sizeof(linger));

    // Send FIN to the client
    shutdown(conn->client.sock, SHUT_WR);
    set_non_blocking_mode(conn->client.sock);

    // Now we know that our FIN is ACK-ed, safe to close
    closesocket(conn->client.sock);
}

static void close_connection(struct mg_connection *conn) {
    conn->must_close = 1;

    if(conn->ssl != NULL) {
        // Run SSL_shutdown twice to ensure completly close SSL connection
        SSL_shutdown(conn->ssl);
        SSL_free(conn->ssl);
        conn->ssl = NULL;
    }

    if(conn->client.sock != INVALID_SOCKET) {
        close_socket_gracefully(conn);
        conn->client.sock = INVALID_SOCKET;
    }
}

struct mg_connection *mg_connect(const char *host, int port, int use_ssl,
                                 char *ebuf, size_t ebuf_len) {
    static struct mg_context fake_ctx;
    struct mg_connection *conn = NULL;
    SOCKET sock;

    if((sock = conn2(host, port, use_ssl, ebuf, ebuf_len)) == INVALID_SOCKET) {
    } else if((conn = (struct mg_connection *)
                            calloc(1, sizeof(*conn) + MAX_REQUEST_SIZE)) == NULL) {
        snprintf(ebuf, ebuf_len, "calloc(): %s", strerror(errno));
        closesocket(sock);
    } else if(use_ssl && (conn->client_ssl_ctx =
                                                 SSL_CTX_new(SSLv23_client_method())) == NULL) {
        snprintf(ebuf, ebuf_len, "SSL_CTX_new error");
        closesocket(sock);
        free(conn);
        conn = NULL;
    } else {
        socklen_t len = sizeof(struct sockaddr);
        conn->buf_size = MAX_REQUEST_SIZE;
        conn->buf = (char *) (conn + 1);
        conn->ctx = &fake_ctx;
        conn->client.sock = sock;
        getsockname(sock, &conn->client.rsa.sa, &len);
        conn->client.is_ssl = use_ssl;
        if(use_ssl) {
            // SSL_CTX_set_verify call is needed to switch off server certificate
            // checking, which is off by default in OpenSSL and on in yaSSL.
            SSL_CTX_set_verify(conn->client_ssl_ctx, 0, 0);
            sslize(conn, conn->client_ssl_ctx, SSL_connect);
        }
    }

    return conn;
}

static int is_valid_uri(const char *uri) {
    // Conform to http://www.w3.org/Protocols/rfc2616/rfc2616-sec5.html#sec5.1.2
    // URI can be an asterisk (*) or should start with slash.
    return uri[0] == '/' || (uri[0] == '*' && uri[1] == '\0');
}

static int getreq(struct mg_connection *conn, char *ebuf, size_t ebuf_len) {
    const char *cl;

    ebuf[0] = '\0';
    reset_per_request_attributes(conn);
    conn->request_len = read_request(NULL, conn, conn->buf, conn->buf_size,
                                                                     &conn->data_len);
    assert(conn->request_len < 0 || conn->data_len >= conn->request_len);

    if(conn->request_len == 0 && conn->data_len == conn->buf_size) {
        snprintf(ebuf, ebuf_len, "%s", "Request Too Large");
    } else if(conn->request_len <= 0) {
        snprintf(ebuf, ebuf_len, "%s", "Client closed connection");
    } else if(parse_http_message(conn->buf, conn->buf_size,
                                                                &conn->request_info) <= 0) {
        snprintf(ebuf, ebuf_len, "Bad request: [%.*s]", conn->data_len, conn->buf);
    } else {
        // Request is valid
        if((cl = get_header(&conn->request_info, "Content-Length")) != NULL) {
            conn->content_len = strtoll(cl, NULL, 10);
        } else if(!strcasecmp(conn->request_info.request_method, "POST") ||
                             !strcasecmp(conn->request_info.request_method, "PUT")) {
            conn->content_len = -1;
        } else {
            conn->content_len = 0;
        }
        conn->birth_time = time(NULL);
    }
    return ebuf[0] == '\0';
}

static void process_new_connection(struct mg_connection *conn) {
    struct mg_request_info *ri = &conn->request_info;
    int keep_alive_enabled, keep_alive, discard_len;
    char ebuf[100];

    keep_alive_enabled = !strcmp(conn->ctx->config[ENABLE_KEEP_ALIVE], "yes");

    // Important: on new connection, reset the receiving buffer. Credit goes
    // to crule42.
    conn->data_len = 0;
    do {
        if(!getreq(conn, ebuf, sizeof(ebuf))) {
            send_http_error(conn, 500, "Server Error", "%s", ebuf);
            conn->must_close = 1;
        } else if(!is_valid_uri(conn->request_info.uri)) {
            snprintf(ebuf, sizeof(ebuf), "Invalid URI: [%s]", ri->uri);
            send_http_error(conn, 400, "Bad Request", "%s", ebuf);
        } else if(strcmp(ri->http_version, "1.0") &&
                  strcmp(ri->http_version, "1.1")) {
            snprintf(ebuf, sizeof(ebuf), "Bad HTTP version: [%s]", ri->http_version);
            send_http_error(conn, 505, "Bad HTTP version", "%s", ebuf);
        }

        if(ebuf[0] == '\0') {
            handle_request(conn);
            if(conn->ctx->callbacks.end_request != NULL) {
                conn->ctx->callbacks.end_request(conn, conn->status_code);
            }
            log_access(conn);
        }
        if(ri->remote_user != NULL) {
            free((void *) ri->remote_user);
            // Important! When having connections with and without auth
            // would cause double free and then crash
            ri->remote_user = NULL;
        }

        // NOTE(lsm): order is important here. should_keep_alive() call
        // is using parsed request, which will be invalid after memmove's below.
        // Therefore, memorize should_keep_alive() result now for later use
        // in loop exit condition.
        keep_alive = conn->ctx->stop_flag == 0 && keep_alive_enabled &&
            conn->content_len >= 0 && should_keep_alive(conn);

        // Discard all buffered data for this request
        discard_len = conn->content_len >= 0 && conn->request_len > 0 &&
            conn->request_len + conn->content_len < (int64_t) conn->data_len ?
            (int) (conn->request_len + conn->content_len) : conn->data_len;
        assert(discard_len >= 0);
        memmove(conn->buf, conn->buf + discard_len, conn->data_len - discard_len);
        conn->data_len -= discard_len;
        assert(conn->data_len >= 0);
        assert(conn->data_len <= conn->buf_size);
    } while(keep_alive);
}

// Worker threads take accepted socket from the queue
static int consume_socket(struct mg_context *ctx, struct socket *sp) {
    (void) pthread_mutex_lock(&ctx->mutex);
    DEBUG_TRACE(("going idle"));

    // If the queue is empty, wait. We're idle at this point.
    while(ctx->sq_head == ctx->sq_tail && ctx->stop_flag == 0) {
        pthread_cond_wait(&ctx->sq_full, &ctx->mutex);
    }

    // If we're stopping, sq_head may be equal to sq_tail.
    if(ctx->sq_head > ctx->sq_tail) {
        // Copy socket from the queue and increment tail
        *sp = ctx->queue[ctx->sq_tail % ARRAY_SIZE(ctx->queue)];
        ctx->sq_tail++;
        DEBUG_TRACE(("grabbed socket %d, going busy", sp->sock));

        // Wrap pointers if needed
        while(ctx->sq_tail > (int) ARRAY_SIZE(ctx->queue)) {
            ctx->sq_tail -= ARRAY_SIZE(ctx->queue);
            ctx->sq_head -= ARRAY_SIZE(ctx->queue);
        }
    }

    (void) pthread_cond_signal(&ctx->sq_empty);
    (void) pthread_mutex_unlock(&ctx->mutex);

    return !ctx->stop_flag;
}

static void *worker_thread(void *thread_func_param) {
    struct mg_context *ctx = (struct mg_context *) thread_func_param;
    struct mg_connection *conn;

    conn = (struct mg_connection *) calloc(1, sizeof(*conn) + MAX_REQUEST_SIZE);
    if(conn == NULL) {
        cry(fc(ctx), "%s", "Cannot create new connection struct, OOM");
    } else {
        conn->buf_size = MAX_REQUEST_SIZE;
        conn->buf = (char *) (conn + 1);
        conn->ctx = ctx;
        conn->request_info.user_data = ctx->user_data;

        // Call consume_socket() even when ctx->stop_flag > 0, to let it signal
        // sq_empty condvar to wake up the master waiting in produce_socket()
        while(consume_socket(ctx, &conn->client)) {
            conn->birth_time = time(NULL);

            // Fill in IP, port info early so even if SSL setup below fails,
            // error handler would have the corresponding info.
            // Thanks to Johannes Winkelmann for the patch.
            // TODO(lsm): Fix IPv6 case
            conn->request_info.remote_port = ntohs(conn->client.rsa.sin.sin_port);
            memcpy(&conn->request_info.remote_ip,
                         &conn->client.rsa.sin.sin_addr.s_addr, 4);
            conn->request_info.remote_ip = ntohl(conn->request_info.remote_ip);
            conn->request_info.is_ssl = conn->client.is_ssl;

            if(!conn->client.is_ssl
                    || sslize(conn, conn->ctx->ssl_ctx, SSL_accept)
                 ) {
                process_new_connection(conn);
            }

            close_connection(conn);
        }
        free(conn);
    }

    // Signal master that we're done with connection and exiting
    (void) pthread_mutex_lock(&ctx->mutex);
    ctx->num_threads--;
    (void) pthread_cond_signal(&ctx->cond);
    assert(ctx->num_threads >= 0);
    (void) pthread_mutex_unlock(&ctx->mutex);

    DEBUG_TRACE(("exiting"));
    return NULL;
}

// Master thread adds accepted socket to a queue
static void produce_socket(struct mg_context *ctx, const struct socket *sp) {
    (void) pthread_mutex_lock(&ctx->mutex);

    // If the queue is full, wait
    while(ctx->stop_flag == 0 &&
                 ctx->sq_head - ctx->sq_tail >= (int) ARRAY_SIZE(ctx->queue)) {
        (void) pthread_cond_wait(&ctx->sq_empty, &ctx->mutex);
    }

    if(ctx->sq_head - ctx->sq_tail < (int) ARRAY_SIZE(ctx->queue)) {
        // Copy socket to the queue and increment head
        ctx->queue[ctx->sq_head % ARRAY_SIZE(ctx->queue)] = *sp;
        ctx->sq_head++;
        DEBUG_TRACE(("queued socket %d", sp->sock));
    }

    (void) pthread_cond_signal(&ctx->sq_full);
    (void) pthread_mutex_unlock(&ctx->mutex);
}

static int set_sock_timeout(SOCKET sock, int milliseconds) {
    struct timeval t;
    t.tv_sec = milliseconds / 1000;
    t.tv_usec = (milliseconds * 1000) % 1000000;

    return setsockopt(sock, SOL_SOCKET, SO_RCVTIMEO, (void *) &t, sizeof(t)) ||
        setsockopt(sock, SOL_SOCKET, SO_SNDTIMEO, (void *) &t, sizeof(t));
}

static void accept_new_connection(const struct socket *listener,
                                  struct mg_context *ctx) {
    struct socket so;
    char src_addr[IP_ADDR_STR_LEN];
    socklen_t len = sizeof(so.rsa);
    int on = 1;

    if((so.sock = accept(listener->sock, &so.rsa.sa, &len)) == INVALID_SOCKET) {
    } else if(!check_acl(ctx, ntohl(* (uint32_t *) &so.rsa.sin.sin_addr))) {
        sockaddr_to_string(src_addr, sizeof(src_addr), &so.rsa);
        cry(fc(ctx), "%s: %s is not allowed to connect", __func__, src_addr);
        closesocket(so.sock);
    } else {
        // Put so socket structure into the queue
        DEBUG_TRACE(("Accepted socket %d", (int) so.sock));
        set_close_on_exec(so.sock);
        so.is_ssl = listener->is_ssl;
        so.ssl_redir = listener->ssl_redir;
        getsockname(so.sock, &so.lsa.sa, &len);
        // Set TCP keep-alive. This is needed because if HTTP-level keep-alive
        // is enabled, and client resets the connection, server won't get
        // TCP FIN or RST and will keep the connection open forever. With TCP
        // keep-alive, next keep-alive handshake will figure out that the client
        // is down and will close the server end.
        // Thanks to Igor Klopov who suggested the patch.
        setsockopt(so.sock, SOL_SOCKET, SO_KEEPALIVE, (void *) &on, sizeof(on));
        set_sock_timeout(so.sock, atoi(ctx->config[REQUEST_TIMEOUT]));
        produce_socket(ctx, &so);
    }
}

static void *master_thread(void *thread_func_param) {
    struct mg_context *ctx = (struct mg_context *) thread_func_param;
    struct pollfd *pfd;
    int i;

    // Increase priority of the master thread
#if defined(ISSUE_317)
    struct sched_param sched_param;
    sched_param.sched_priority = sched_get_priority_max(SCHED_RR);
    pthread_setschedparam(pthread_self(), SCHED_RR, &sched_param);
#endif

    pfd = (struct pollfd *) calloc(ctx->num_listening_sockets, sizeof(pfd[0]));
    while(pfd != NULL && ctx->stop_flag == 0) {
        for(i = 0; i < ctx->num_listening_sockets; i++) {
            pfd[i].fd = ctx->listening_sockets[i].sock;
            pfd[i].events = POLLIN;
        }

        if(poll(pfd, ctx->num_listening_sockets, 200) > 0) {
            for(i = 0; i < ctx->num_listening_sockets; i++) {
                // NOTE(lsm): on QNX, poll() returns POLLRDNORM after the
                // successfull poll, and POLLIN is defined as (POLLRDNORM | POLLRDBAND)
                // Therefore, we're checking pfd[i].revents & POLLIN, not
                // pfd[i].revents == POLLIN.
                if(ctx->stop_flag == 0 && (pfd[i].revents & POLLIN)) {
                    accept_new_connection(&ctx->listening_sockets[i], ctx);
                }
            }
        }
    }
    free(pfd);
    DEBUG_TRACE(("stopping workers"));

    // Stop signal received: somebody called mg_stop. Quit.
    close_all_listening_sockets(ctx);

    // Wakeup workers that are waiting for connections to handle.
    pthread_cond_broadcast(&ctx->sq_full);

    // Wait until all threads finish
    (void) pthread_mutex_lock(&ctx->mutex);
    while(ctx->num_threads > 0) {
        (void) pthread_cond_wait(&ctx->cond, &ctx->mutex);
    }
    (void) pthread_mutex_unlock(&ctx->mutex);

    // All threads exited, no sync is needed. Destroy mutex and condvars
    (void) pthread_mutex_destroy(&ctx->mutex);
    (void) pthread_cond_destroy(&ctx->cond);
    (void) pthread_cond_destroy(&ctx->sq_empty);
    (void) pthread_cond_destroy(&ctx->sq_full);

    uninitialize_ssl(ctx);
    DEBUG_TRACE(("exiting"));

    // Signal mg_stop() that we're done.
    // WARNING: This must be the very last thing this
    // thread does, as ctx becomes invalid after this line.
    ctx->stop_flag = 2;
    return NULL;
}

static void free_context(struct mg_context *ctx) {
    int i;

    // Deallocate config parameters
    for(i = 0; i < NUM_OPTIONS; i++) {
        if(ctx->config[i] != NULL)
            free(ctx->config[i]);
    }

    // Deallocate SSL context
    if(ctx->ssl_ctx != NULL) {
        SSL_CTX_free(ctx->ssl_ctx);
    }
    if(ssl_mutexes != NULL) {
        free(ssl_mutexes);
        ssl_mutexes = NULL;
    }

    // Deallocate context itself
    free(ctx);
}

void mg_stop(struct mg_context *ctx) {
    ctx->stop_flag = 1;

    // Wait until mg_fini() stops
    while(ctx->stop_flag != 2) {
        (void) mg_sleep(10);
    }
    free_context(ctx);
}

struct mg_context *mg_start(const struct mg_callbacks *callbacks,
                            void *user_data,
                            const char **options) {
    struct mg_context *ctx;
    const char *name, *value, *default_value;
    int i;

    // Allocate context and initialize reasonable general case defaults.
    // TODO(lsm): do proper error handling here.
    if((ctx = (struct mg_context *) calloc(1, sizeof(*ctx))) == NULL) {
        return NULL;
    }
    ctx->callbacks = *callbacks;
    ctx->user_data = user_data;

    while(options && (name = *options++) != NULL) {
        if((i = get_option_index(name)) == -1) {
            cry(fc(ctx), "Invalid option: %s", name);
            free_context(ctx);
            return NULL;
        } else if((value = *options++) == NULL) {
            cry(fc(ctx), "%s: option value cannot be NULL", name);
            free_context(ctx);
            return NULL;
        }
        if(ctx->config[i] != NULL) {
            cry(fc(ctx), "warning: %s: duplicate option", name);
            free(ctx->config[i]);
        }
        ctx->config[i] = strdup(value);
        DEBUG_TRACE(("[%s] -> [%s]", name, value));
    }

    // Set default value if needed
    for(i = 0; config_options[i * 2] != NULL; i++) {
        default_value = config_options[i * 2 + 1];
        if(ctx->config[i] == NULL && default_value != NULL) {
            ctx->config[i] = strdup(default_value);
        }
    }

    // NOTE(lsm): order is important here. SSL certificates must
    // be initialized before listening ports. UID must be set last.
    if(!set_gpass_option(ctx) ||
       !set_ssl_option(ctx)   ||
       !set_ports_option(ctx) ||
       !set_uid_option(ctx)   ||
       !set_acl_option(ctx)) {
        free_context(ctx);
        return NULL;
    }

    // Ignore SIGPIPE signal, so if browser cancels the request, it
    // won't kill the whole process.
    (void) signal(SIGPIPE, SIG_IGN);
    // Also ignoring SIGCHLD to let the OS to reap zombies properly.
    (void) signal(SIGCHLD, SIG_IGN);

    (void) pthread_mutex_init(&ctx->mutex, NULL);
    (void) pthread_cond_init(&ctx->cond, NULL);
    (void) pthread_cond_init(&ctx->sq_empty, NULL);
    (void) pthread_cond_init(&ctx->sq_full, NULL);

    // Start master (listening) thread
    mg_start_thread(master_thread, ctx);

    // Start worker threads
    for(i = 0; i < atoi(ctx->config[NUM_THREADS]); i++) {
        if(mg_start_thread(worker_thread, ctx) != 0) {
            cry(fc(ctx), "Cannot start worker thread: %ld", (long) errno);
        } else {
            ctx->num_threads++;
        }
    }

    return ctx;
}

int test_some_shit2() {
	return 31337;
}

