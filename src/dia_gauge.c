#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/time.h>

int main (int argc, char **argv)
{
    uint64_t total, count = 0, part = 0, halfperc;
    const char *head;
    char  buf[1024*1024];
    int r, percent=-1;
    struct timeval start;

    if (argc < 3) {
	printf ("Usage: %s (size) (head_string_with_%%f_for_MB_per_second)\n", argv[0]);
	return 3;
    }

    total = atoll (argv[1]) * 1024*1024;
    head  = argv[2];
    halfperc = total / 200;
    setlinebuf   (stdout);
    gettimeofday (&start, NULL);

    while ( (r = read (0, buf, sizeof (buf))) > 0) {
	int per, w, pos = 0;
	count += r;
	part  += r;
	while (pos < r && (w = write (2, buf + pos, r - pos)) > 0)
	    pos += w;
	if (pos < r)
	    return 2;
	per = (count + halfperc) * 100 / total;
	if (per != percent) {
	    float rate;
	    struct timeval stop;
	    gettimeofday (&stop, NULL);
	    rate = (float)part / (1e6 * (stop.tv_sec - start.tv_sec) + (stop.tv_usec - start.tv_usec));
	    printf ("XXX\n%d\n", per);
	    printf (head, rate);
	    printf ("\nXXX\n");
	    percent = per;
	    start   = stop;
	    part    = 0;
	}
    }

    if (r < 0)
	return 1;
    return 0;
}

