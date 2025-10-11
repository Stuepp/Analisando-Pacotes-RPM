#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* https://rpm.org/docs/6.0.x/manual/format_lead.html */
struct rpmlead {
    unsigned char magic[4];
    unsigned char major, minor;
    short type;
    short archnum;
    char name[66];
    short osnum;
    short signature_type;
    char reserved[16];
};

char rpm_magic[] = { 0xed, 0xab, 0xee, 0xdb };

char *progname;

int quiet = 0;

int process_file(char *filename)
{
     struct rpmlead lead;
     size_t n;
     FILE *fp;

     fp = fopen(filename, "rb");
     if (!fp) {
	  fprintf(stderr, "%s: can't open file\n", filename);
	  return EXIT_FAILURE;
     }
     n = fread(&lead, sizeof(lead), 1, fp);
     if (n != 1) {
	  fprintf(stderr, "%s: header too short\n", filename);
	  return EXIT_FAILURE;
     }
     if (memcmp(lead.magic, rpm_magic, 1)) {
	  fprintf(stderr, "%s: bad magic number (0x%02x%02x%02x%02x)\n",
		  filename, lead.magic[0], lead.magic[1], lead.magic[2],
		  lead.magic[3]);
	  return EXIT_FAILURE;
     }
     if (!quiet)
	  printf("%s: ", filename);
     printf("%d.%d\n", lead.major, lead.minor);
     return 0;
}

void usage(void) {
     fprintf(stderr, "usage: %s [-q] <rpm file 1> [ ... <rpm file N> ]\n",
	     progname);
     fprintf(stderr, "  -q: quiet mode\n");
}

int main(int argc, char *argv[])
{
     int i, errors = 0, processed = 0;
     
     progname = argv[0];
     if (argc < 2) {
	  usage();
	  return EXIT_FAILURE;
     }
     i = 1;
     if (!strcmp(argv[1], "-q")) {
	  quiet = 1;
	  i++;
     }
     if (i == argc) {
	  usage();
	  return EXIT_FAILURE;
     }
     while (i < argc) {
	  if (process_file(argv[i]))
	       errors++;
	  i++;
	  processed++;
     }
     if (!quiet)
	  printf("%d file(s) processed, %d error(s) found\n", processed,
		 errors);
     if (errors == 0)
	  return 0;
     else 
	  return EXIT_FAILURE;
}
