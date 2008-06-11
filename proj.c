#include <stdio.h>
#include <stdlib.h>
#include <time.h>

typedef struct
{
	unsigned short skip; /* These two bytes are not in the file header*/
	/* BITMAP FILE HEADER: <- Beginning of the file */
	unsigned short fType; /* Specifies the file type. Must be 0x4D42 */
	unsigned int fSize; /* Specifies the size, in bytes, of the file */
	unsigned int fReservedFlags;/* Reserved; must be 0x00000000 */
	unsigned int fOffBits; /* Offset, in bytes: 0x28 + palette_size */
	/* BITMAP INFO HEADER: */
	unsigned int bSize; /* Bytes required by the structure: 0x28 */
	int width; /* Bitmap width */
	int height; /* Bitmap height */
	short int bPlanes; /* Must be 0x0001 */
	short int bpp; /* Bits per pixel: 8,24 or 32 */
	unsigned int bCompression; /* Should be BI_RGB (0) for uncompressed */
	unsigned int bSizeImage; /* 0 for BI_RGB */
	int bXPelsPerMeter; /* Not important */
	int bYPelsPerMeter; /* Not important */
	unsigned int bClrUsed; /* Not important */
	unsigned int bClrImportant;/* Not important */
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

extern void rectBlur (unsigned char* inputBMP, int width, int height, unsigned char* outputBMP, int w, int h);

int main(void) {
	clock_t ticks;

	BMPHeader head[5];
	ticks = clock();
	unsigned char* input1 = loadBMP("test_01.bmp",&head[0]);
	unsigned char* input2 = loadBMP("test_02.bmp",&head[1]);
	unsigned char* input3 = loadBMP("test_03.bmp",&head[2]);
	unsigned char* input4 = loadBMP("test_04.bmp",&head[3]);
	
	unsigned char* output1[5];
	unsigned char* output2[5];
	unsigned char* output3[5];
	unsigned char* output4[5];

	int i, x, z;
	for (i = 0; i < 5; ++i) {
		output1[i] = malloc(head[0].bSizeImage);
		output2[i] = malloc(head[1].bSizeImage);
		output4[i] = malloc(head[3].bSizeImage);
	}
	output3[0] = malloc(head[2].bSizeImage);

	ticks = clock();
	
	x = 0;

	for (i = 1; i < 11; i += 3) {
		for (z = 0; z < ((-(i-10))^2)+1; ++z) {
			rectBlur(input1, head[0].width, head[0].height, output1[x], i, i);
			rectBlur(input2, head[1].width, head[1].height, output2[x], i, i);
			rectBlur(input4, head[3].width, head[3].height, output4[x], i, i);

		}
		++x;
	}
	rectBlur(input1, head[0].width, head[0].height, output1[4], 35, 35);
	rectBlur(input2, head[1].width, head[1].height, output2[4], 35, 35);
	rectBlur(input3, head[2].width, head[2].height, output3[0], 5, 5);
	rectBlur(input4, head[3].width, head[3].height, output4[4], 35, 35);

	ticks = clock() - ticks;
	double l = ticks;
	l /= CLOCKS_PER_SEC;
	printf("Processing: %d == %.3fs\n", (int)ticks, l);

	ticks = clock();

	char fileout[20];

	for (i = 0; i < 5; ++i) {
		sprintf(fileout, "testout_01_%d.bmp", i+1);
		saveBMP(fileout, &head[0], output1[i]);
		sprintf(fileout, "testout_02_%d.bmp", i+1);
		saveBMP(fileout, &head[1], output2[i]);
		sprintf(fileout, "testout_04_%d.bmp", i+1);
		saveBMP(fileout, &head[3], output4[i]);
	}
		sprintf(fileout, "testout_03_%d.bmp", 1);
		saveBMP(fileout, &head[2], output3[0]);
	free(input1);
	free(input2);
	free(input3);
	free(input4);
	
	for (i = 0; i < 5; ++i) {
		free(output1[i]);
		free(output2[i]);
		free(output4[i]);
	}
	free(output3[0]);
	ticks = clock() - ticks;
	printf("Write to disk: %d == %dms\n", (int)ticks, (int)(ticks*1000/CLOCKS_PER_SEC));

	return 0;
}

