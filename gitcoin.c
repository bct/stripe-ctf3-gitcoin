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

  char object_header[16];
  char header[1024];

  header[0] = 0;

  // the nice thing about a git object is that the bit we can control (the
  // commit message) comes last, so we can generate a fixed header here and 
  // just append the generated nonce at the end.
  strcat(header, head_tree);
  strcat(header, tree);
  strcat(header, head_parent);
  strcat(header, parent);
  strcat(header, head_author);
  strcat(header, head_committer);

  unsigned int object_length = strlen(header) + 10;

  // a git object has a header containing the type of the object type and its
  // length in bytes. it took forever to figure this out.
  sprintf(object_header, "%s%d", head_object, object_length);

  fprintf(stderr, "%s\n", header);

  int counter = atoi(initial_counter);

  // this is used in a select call that times out immediately to see if our
  // parent is still listening. there's probably a better way to do this.
  fd_set the_fd_set;
  struct timeval timeout;

  timeout.tv_sec = 0;
  timeout.tv_usec = 1;

  // start initializing our OpenSSL stuff
  unsigned char result_sha1[21];
  char result_sha1_hex[41];

  char nonce[11];

  OpenSSL_add_all_digests();

  const EVP_MD *md = EVP_sha1();

  // initialize a base message digest context containing the fixed part of the
  // object.
  EVP_MD_CTX *basectx = EVP_MD_CTX_create();
  basectx = EVP_MD_CTX_create();
  EVP_DigestInit_ex(basectx, md, NULL);

  EVP_DigestUpdate(basectx, object_header, strlen(object_header) + 1);
  EVP_DigestUpdate(basectx, header, strlen(header));

  // initialize a message digest context to copy the base context into.
  EVP_MD_CTX mdctx;
  EVP_MD_CTX_init(&mdctx);
  EVP_DigestInit_ex(&mdctx, md, NULL);

  while(1) {
    counter++;

    sprintf(nonce, "%010x", counter);

    if(counter % 0x07ffff == 0) {
      // every once in a while print a status

      fprintf(stderr, "%s\n", nonce);

      FD_ZERO(&the_fd_set);
      FD_SET(STDOUT_FILENO, &the_fd_set);

      // check if the parent is still listening
      if(select(STDOUT_FILENO + 1, &the_fd_set, NULL, NULL, &timeout)) {
        // our parent is done with us, we should exit
        exit(0);
      }
    }

    // copy the base context into the actual message digest we're going to use
    // this is faster than redigesting the fixed header every time we loop.
    EVP_MD_CTX_copy_ex(&mdctx, basectx);

    // update the message digest with our nonce.
    unsigned int md_len;
    EVP_DigestUpdate(&mdctx, nonce, 10);
    EVP_DigestFinal_ex(&mdctx, result_sha1, &md_len);

    // convert our SHA1 into a hex string and compare it with the difficulty
    // (I imagine it would be faster to convert the difficulty to an integer and
    // compare that instead)
    sha1_to_hex(result_sha1, result_sha1_hex);

    if(strcmp(result_sha1_hex, difficulty) < 0) {
      // we found something!
      fprintf(stderr, "######## I've got something, sir! ########\n");

      // send the result back to our parent on stdout
      puts(result_sha1_hex);
      printf(header);
      printf(nonce);

      exit(0);
    }

    // keep looking!
  }
}
