#include <errno.h>
#include <fcntl.h>
#include <mpi/mpi.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <time.h>
#include <unistd.h>

#define KB(x) (x * 1024ull)
#define MB(x) (KB(x) * 1024ull)
#define GB(x) (MB(x) * 1024ull)

#define COMPLAIN_MSG(msg) fprintf(stderr, "%s\n", msg);

#define COMPLAIN(ret, err_msg, retflag, retcode)                               \
  if (ret) {                                                                   \
    fprintf(stderr, "%s: %s\n", err_msg, strerror(errno));                     \
    if (retflag)                                                               \
      return retcode;                                                          \
  }

struct WriterOpts {
  const char *fpath;
  int write_method;
  size_t blocksz;
  size_t fsize;
  MPI_Comm comm;
};

void Usage() {
  fprintf(stderr, "./prog -b block_size (MB) -p path_to_write"
                  " -s file_size (MB) -w (0 or 1)\n");
  exit(-1);
}

void PrintOpts(const WriterOpts &opts) {
  fprintf(stdout, "Root Dir: \t%s\n", opts.fpath);
  fprintf(stdout, "Write Method: \t%d\n", opts.write_method);
  fprintf(stdout, "BlkSz (MB): \t%llu\n", opts.blocksz / MB(1));
  fprintf(stdout, "FSz (MB): \t%llu\n", opts.fsize / MB(1));
}

void ParseOpts(int argc, char *argv[], WriterOpts &opts) {
  opts.fpath = nullptr;
  opts.write_method = -1;
  opts.blocksz = 0;
  opts.fsize = 0;

  char c;
  while ((c = getopt(argc, argv, "b:p:s:w:")) != -1) {
    switch (c) {
    case 'b':
      opts.blocksz = strtol(optarg, nullptr, 10) * MB(1);
      break;
    case 'p':
      opts.fpath = optarg;
      break;
    case 's':
      opts.fsize = strtol(optarg, nullptr, 10) * MB(1);
      break;
    case 'w':
      opts.write_method = strtol(optarg, nullptr, 10);
      break;
    default:
      Usage();
      break;
    }
  }

  if ((opts.fpath == nullptr) or (opts.write_method == -1) or
      (opts.blocksz == 0) or (opts.fsize == 0)) {
    Usage();
  }
}

class Writer {
public:
  Writer(const WriterOpts &opts)
      : opts_(opts), blocksz_(opts.blocksz), fsize_(opts.fsize) {}

  int Run() {
    const size_t fnamesz = 4096;
    char fname[fnamesz];
    snprintf(fname, fnamesz, "%s/test.dat", opts_.fpath);
    fprintf(stdout, "Writing: %s\n", fname);

    uint64_t ts_beg = Now();
    int rv = WriteFile(fname);
    if (rv)
      return rv;
    uint64_t ts_end = Now();

    PrintBW(fsize_, ts_end - ts_beg);

    return 0;
  }

  int WriteFile(const char *const fname) {
    mode_t fmode = S_IRUSR | S_IWUSR;
    int fd = open(fname, O_RDWR | O_CREAT, fmode);
    COMPLAIN(fd < 0, "Unable to open file", true, -1);

    int rv = Write(fd);
    COMPLAIN(rv, "Write failed", true, -1);

    rv = fsync(fd);
    COMPLAIN(rv, "Fsync failed", true, -1);

    rv = close(fd);
    COMPLAIN(rv, "Close failed", true, -1);

    return 0;
  }

  int Write(int fd) {
    if (opts_.write_method == 0) {
      return WriteSeek(fd);
    } else {
      return WriteNoseek(fd);
    }
  }

  int WriteSeek(int fd) {
    char buf[blocksz_];

    if (fsize_ % blocksz_) {
      COMPLAIN_MSG("fsize must be a multiple of blocksz");
      return -1;
    }

    size_t bytes_out = 0;
    while (bytes_out < fsize_) {
      size_t bytes_rem = fsize_ - bytes_out;
      size_t write_sz = bytes_rem < blocksz_ ? bytes_rem : blocksz_;

      /* simple way to generate a marginally different buffer every time */
      FillBuf(buf, blocksz_, bytes_rem);

      int rv = lseek(fd, bytes_out, SEEK_SET);
      ssize_t bytes_cur = write(fd, buf, write_sz);
      COMPLAIN(bytes_cur < blocksz_, "write() syscall failed", true, -1);

      bytes_out += bytes_cur;
    }

    return 0;
  };

  int WriteNoseek(int fd) {
    char buf[blocksz_];

    size_t bytes_out = 0;
    while (bytes_out < fsize_) {
      size_t bytes_rem = fsize_ - bytes_out;
      size_t write_sz = bytes_rem < blocksz_ ? bytes_rem : blocksz_;

      /* simple way to generate a marginally different buffer every time */
      FillBuf(buf, blocksz_, bytes_rem);

      ssize_t bytes_cur = write(fd, buf, write_sz);
      COMPLAIN(bytes_cur < 0, "write() syscall failed", true, -1);

      bytes_out += bytes_cur;
    }

    return 0;
  };

protected:
  uint64_t Now() {
    struct timespec tp;
    clock_gettime(CLOCK_MONOTONIC, &tp);

    uint64_t time_us = tp.tv_sec * 1e6 + tp.tv_nsec * 1e-3;
    return time_us;
  }

  void PrintBW(uint64_t data_bytes, uint64_t time_us) {
    float fsz_mb = data_bytes * 1.0f / (MB(1) * 1.0f);
    float tsec = time_us * 1e-6;
    float bw_mbps = fsz_mb / tsec;

    fprintf(stdout, "Data Written: %.2f MB\n", fsz_mb);
    fprintf(stdout, "Time (s): %.1fs\n", tsec);
    fprintf(stdout, "Bandwidth: %.2f MB/s\n", bw_mbps);
  }

  void FillBuf(char *buf, size_t bufsz, size_t randval) {
    size_t ptr = 0;
    while (ptr < bufsz) {
      buf[ptr] = ((ptr + randval) % 256);
      ptr += 8;
    }
  }

  const WriterOpts opts_;
  const size_t blocksz_;
  const size_t fsize_;
};

class MPIWriter : public Writer {
public:
  MPIWriter(const WriterOpts &opts)
      : Writer(opts), comm_(opts.comm), worldsz_(-1), myrank_(-1) {
    MPI_Comm_size(comm_, &worldsz_);
    MPI_Comm_rank(comm_, &myrank_);

    if (myrank_ == 0) {
      PrintOpts(opts_);
    }
  }

  int Run() {
    const size_t fnamesz = 4096;
    char fname[fnamesz];
    snprintf(fname, fnamesz, "%s/test.%d.dat", opts_.fpath, myrank_);

    MPI_Barrier(comm_);
    uint64_t ts_beg = Now();
    WriteFile(fname);
    uint64_t ts_end = Now();
    MPI_Barrier(comm_);

    uint64_t ts_delta = ts_end - ts_beg;

    uint64_t ts_delta_max;
    uint64_t data_wrtotal = fsize_ * worldsz_;
    int rv = MPI_Reduce(&ts_delta, &ts_delta_max, 1, MPI_UINT64_T, MPI_MAX, 0,
                        comm_);

    COMPLAIN(rv != MPI_SUCCESS, "MPI_Reduce failed", true, -1);

    if (myrank_ == 0) {
      PrintBW(data_wrtotal, ts_delta_max);
    }

    return 0;
  };

private:
  const MPI_Comm comm_;
  int worldsz_;
  int myrank_;
};

int main(int argc, char *argv[]) {
  WriterOpts opts;
  ParseOpts(argc, argv, opts);
  opts.comm = MPI_COMM_WORLD;
  MPI_Init(&argc, &argv);
  MPIWriter w(opts);
  w.Run();
  MPI_Finalize();
  return 0;
}
