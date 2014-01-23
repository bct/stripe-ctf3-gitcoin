#include <stdio.h>
#include <stdlib.h>
#include <sys/ioctl.h>
#include <sys/socket.h>
#include <sys/time.h>
#include <netinet/in.h>
#include <errno.h>
#include <unistd.h>

#include <string.h>

#include <openssl/evp.h>

void sha1_to_hex(const unsigned char* sha1_bin, char* sha1_hex) {
  int i;

  for(i = 0; i < 20; i++) {
    sprintf(sha1_hex + 2*i, "%02x", sha1_bin[i]);
  }

  sha1_hex[40] = 0;
}

const char *head_object = "commit ";
const char *head_tree = "tree ";
const char *head_parent = "\nparent ";
const char *head_author = "\nauthor bct <bct@diffeq.com> 0 +0000\n";
const char *head_committer = "committer bct <bct@diffeq.com> 0 +0000\n\n";

int main(int argc, char *argv[]) {

  const char *initial_counter = argv[1];
  const char *tree = argv[2];
  const char *parent = argv[3];
  const char *timestamp = argv[4];
  const char *difficulty = argv[5];

  unsigned char object_header[16];
  unsigned char header[1024];

  header[0] = 0;

  strcat(header, head_tree);
  strcat(header, tree);
  strcat(header, head_parent);
  strcat(header, parent);
  strcat(header, head_author);
  strcat(header, head_committer);

  int object_length = strlen(header) + 10;

  sprintf(object_header, "%s%d", head_object, object_length);

  fprintf(stderr, "%s\n", header);

  int counter = atoi(initial_counter);

  OpenSSL_add_all_digests();

  fd_set the_fd_set;
  struct timeval timeout;

  timeout.tv_sec = 0;
  timeout.tv_usec = 1;

  unsigned char result_sha1[21];
  char result_sha1_hex[41];

  char nonce[11];

  const EVP_MD *md = EVP_sha1();

  EVP_MD_CTX *basectx = EVP_MD_CTX_create();
  basectx = EVP_MD_CTX_create();
  EVP_DigestInit_ex(basectx, md, NULL);

  EVP_DigestUpdate(basectx, object_header, strlen(object_header) + 1);
  EVP_DigestUpdate(basectx, header, strlen(header));

  EVP_MD_CTX mdctx;
  EVP_MD_CTX_init(&mdctx);
  EVP_DigestInit_ex(&mdctx, md, NULL);

  while(1) {
    counter++;

    sprintf(nonce, "%010x", counter);

    if(counter % 0x07ffff == 0) {
      fprintf(stderr, "%s\n", nonce);

      FD_ZERO(&the_fd_set);
      FD_SET(STDOUT_FILENO, &the_fd_set);

      if(select(STDOUT_FILENO + 1, &the_fd_set, NULL, NULL, &timeout)) {
        // our parent is done with us, we should exit
        exit(0);
      }
    }

    EVP_MD_CTX_copy_ex(&mdctx, basectx);

    int md_len;
    EVP_DigestUpdate(&mdctx, nonce, 10);
    EVP_DigestFinal_ex(&mdctx, result_sha1, &md_len);

    sha1_to_hex(result_sha1, result_sha1_hex);

    if(strcmp(result_sha1_hex, difficulty) < 0) {
//    if(counter == 1) {
      // we found something!
      fprintf(stderr, "######## I've got something, sir! ########\n");

      puts(result_sha1_hex);
      printf(header);
      printf(nonce);

      exit(0);
    }
  }
}
