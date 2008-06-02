#include <stdio.h>
#include <stdlib.h>
#include <time.h>

typedef struct
{
	unsigned short skip; 
	unsigned short fType; 
	unsigned int fSize; 
	unsigned int fReservedFlags;
	unsigned int fOffBits;
	unsigned int bSize; 
	int width; 
	int height;
	short int bPlanes;
	short int bpp; 
	unsigned int bCompression;
	unsigned int bSizeImage;
	int bXPelsPerMeter; 
	int bYPelsPerMeter;
	unsigned int bClrUsed; 
	unsigned int bClrImportant;
} BMPHeader;


unsigned char* loadBMP(char* fname, BMPHeader* header) {
	FILE* bmp = fopen(fname, "rb");
	fread((char*)header+2, 1, 54, bmp);

	unsigned char* block = malloc((*header).bSizeImage);
	fread((char*)block, 1, (*header).bSizeImage, bmp);

	fclose(bmp);

	return block;
}

void saveBMP(char* fname, BMPHeader* header, unsigned char* data) {
	FILE* bmp = fopen(fname, "wb");
	fwrite((char*)header+2, 1, 54, bmp);

	fwrite((char*)data, 1, (*header).bSizeImage, bmp);

	fclose(bmp);

	return;
}

extern void rectBLur (unsigned char* inputBMP, int width, int height, unsigned char* outputBMP, int w, int h);

int main(void) {
	clock_t ticks;

	BMPHeader head[5];
	ticks = clock();

	//
	// Wczytanie plików, alokacja pamiêci.
	//

	unsigned char* input1 = loadBMP("test_01.bmp",&head[0]);
	unsigned char* input2 = loadBMP("test_02.bmp",&head[1]);
	unsigned char* input3 = loadBMP("test_03.bmp",&head[2]);
	unsigned char* input4 = loadBMP("test_04.bmp",&head[3]);
	unsigned char* input5 = loadBMP("test_05.bmp",&head[4]);

	unsigned char* output1[6];
	unsigned char* output2[6];
	unsigned char* output3[6];
	unsigned char* output4[6];
	unsigned char* output5[6];

	int i, x, z;
	for (i = 0; i < 6; ++i) {
		output1[i] = malloc(head[0].bSizeImage);
		output2[i] = malloc(head[1].bSizeImage);
		output3[i] = malloc(head[2].bSizeImage);
		output4[i] = malloc(head[3].bSizeImage);
		output5[i] = malloc(head[4].bSizeImage);
	}

	// 
	// Tutaj leci wszelki wasz prerectBluring. Nie mam pojecia co tu mozna wrzucic, wiec odsylam do dokumentacji projektu. ;-)
	//

	ticks = clock() - ticks;
	printf("Pre bluring: %d == %dms\n", (int)ticks, (int)(ticks*1000/CLOCKS_PER_SEC));
	ticks = clock();
	
	//
	// Tutaj jest wlasciwe przetwarzanie. 
	//

	x = 0;

	for (i = 1; i < 3; i += 2) {
		for (z = 0; z < ((-(i-10))^2)+1; ++z) {
			rectBlur(input1, head[0].width, head[0].height, output1[x], i, i);
			rectBlur(input2, head[1].width, head[1].height, output2[x], i, i);
			rectBlur(input3, head[2].width, head[2].height, output3[x], i, i);
			rectBlur(input4, head[3].width, head[3].height, output4[x], i, i);
			rectBlur(input5, head[4].width, head[4].height, output5[x], i, i);
		}
		++x;
	}

	rectBlur(input1, head[0].width, head[0].height, output1[5], 35, 35);
	rectBlur(input2, head[1].width, head[1].height, output2[5], 35, 35);
	rectBlur(input3, head[2].width, head[2].height, output3[5], 35, 35);
	rectBlur(input4, head[3].width, head[3].height, output4[5], 35, 35);
	rectBlur(input5, head[4].width, head[4].height, output5[5], 35, 35);


	ticks = clock() - ticks;
	printf("rectBluring: %d == %dms\n", (int)ticks, (int)(ticks*1000/CLOCKS_PER_SEC));

	ticks = clock();

	//
	//	Zapis plików i uwolnienie pamieci.
	//

	char fileout[20];

	for (i = 0; i < 6; ++i) {
		sprintf(fileout, "testout_01_%d.bmp", i+1);
		saveBMP(fileout, &head[0], output1[i]);
		sprintf(fileout, "testout_02_%d.bmp", i+1);
		saveBMP(fileout, &head[1], output2[i]);
		sprintf(fileout, "testout_03_%d.bmp", i+1);
		saveBMP(fileout, &head[2], output3[i]);
		sprintf(fileout, "testout_04_%d.bmp", i+1);
		saveBMP(fileout, &head[3], output4[i]);
		sprintf(fileout, "testout_05_%d.bmp", i+1);
		saveBMP(fileout, &head[4], output5[i]);
	}
	free(input1);
	free(input2);
	free(input3);
	free(input4);
	free(input5);

	for (i = 0; i < 6; ++i) {
		free(output1[i]);
		free(output2[i]);
		free(output3[i]);
		free(output4[i]);
		free(output5[i]);
	}
	ticks = clock() - ticks;
	printf("Write to disk: %d == %dms\n", (int)ticks, (int)(ticks*1000/CLOCKS_PER_SEC));

	return 0;
}

