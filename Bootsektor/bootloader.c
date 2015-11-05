// Set pointer to videobuffer
char *video = (char*)0xB8000;

int main() {
	// Set string
	char *hello = "Hello World";

        for(video+=4000; video !=(char*)0xB8000; video--) {
                *video=0;
        }

	while(*video) {
		*video=*hello;
		video++;
		*video = 0x07;
		video++;
		hello++;
	}

	while(1);
	return 0;
}
