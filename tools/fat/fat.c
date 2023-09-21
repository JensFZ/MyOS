#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>

typedef uint8_t bool;
#define true 1
#define false 0

typedef struct
{
    uint8_t BootJumpInstruction[3]; // 0xEB 0x3C 0x90
    uint8_t OemIdentifier[8]; // OEM name and version
    uint16_t BytesPerSector; // bytes per sector
    uint8_t SectorsPerCluster;    // sectors per cluster
    uint16_t ReservedSectors;  // reserved sectors
    uint8_t FatCount;    // number of FATs
    uint16_t DirEntryCount; // number of root directory entries
    uint16_t TotalSectors; // total number of sectors
    uint8_t MediaDescriptorType; // media descriptor
    uint16_t SectorsPerFat; // sectors per FAT
    uint16_t SectorsPerTrack; // sectors per track
    uint16_t Heads; // number of heads
    uint32_t HiddenSectors; // hidden sectors
    uint32_t LargeSectorCount; // number of sectors (large)

    uint8_t DriveNumber; // drive number
    uint8_t _Reserved; // reserved
    uint8_t Signature; // signature
    uint32_t VolumeId; // volume ID
    uint8_t VolumeLabel[11]; // volume label
    uint8_t SystemId[8]; // filesystem type
} __attribute__((packed)) BootSector;

typedef struct {
    uint8_t Name[11]; // file name
    uint8_t Attributes; // file attributes
    uint8_t _Reserved;  // reserved
    uint8_t CreatedTimeTenths; // creation time (milliseconds)
    uint16_t CreatedTime; // creation time
    uint16_t CreatedDate; // creation date
    uint16_t AccessedDate; // last access date
    uint16_t FirstClusterHigh; // first cluster (high word)
    uint16_t ModifiedTime; // last modification time
    uint16_t ModifiedDate; // last modification date
    uint16_t FirstClusterLow; // first cluster (low word)
    uint32_t Size; // file size

} __attribute__((packed)) DirectoryEntry;

BootSector g_BootSector; // boot sector
uint8_t* g_Fat = NULL; // FAT
DirectoryEntry* g_RootDirectory = NULL; // root directory
uint32_t g_RootDirectoryEnd; // end of root directory

bool readBootSector(FILE* disk) { // read boot sector
    return fread(&g_BootSector, sizeof(g_BootSector), 1, disk) > 0; // read boot sector
}


bool readSectors(FILE* disk, uint32_t lba, uint32_t count, void* bufferOut) { // read sectors
    bool ok = true;
    ok = ok && (fseek(disk, lba * g_BootSector.BytesPerSector, SEEK_SET) == 0); // seek to the beginning of the sector
    ok = ok && (fread(bufferOut, g_BootSector.BytesPerSector, count, disk) == count); // read the sector
    return ok;
}

bool readFat(FILE* disk) {
    g_Fat = (uint8_t*)malloc(g_BootSector.SectorsPerFat * g_BootSector.BytesPerSector); // allocate memory for FAT
    return readSectors(disk, g_BootSector.ReservedSectors, g_BootSector.SectorsPerFat, g_Fat); // read FAT
}

bool readRootDirectory(FILE* disk) {
    uint32_t lba = g_BootSector.ReservedSectors + g_BootSector.SectorsPerFat * g_BootSector.FatCount; // calculate LBA of root directory
    uint32_t size = sizeof(DirectoryEntry) * g_BootSector.DirEntryCount; // calculate size of root directory
    uint32_t sectors = (size / g_BootSector.BytesPerSector); // calculate number of sectors
    
    if(size % g_BootSector.BytesPerSector > 0) { // if there is a remainder -> round up
        sectors++;
    }

    g_RootDirectoryEnd = lba + sectors; // calculate end of root directory
    g_RootDirectory = (DirectoryEntry*)malloc(sectors * g_BootSector.BytesPerSector); // allocate memory for root directory
    return readSectors(disk, lba, sectors, g_RootDirectory); // read root directory
}

DirectoryEntry* findFile(const char* name) {
    for(uint32_t i = 0; i < g_BootSector.DirEntryCount; i++) { // iterate through root directory
        if(memcmp(name, g_RootDirectory[i].Name, 11) == 0) { // compare file name
            return &g_RootDirectory[i]; // return pointer to directory entry
        }
    }

    return NULL;
}

bool readFile(DirectoryEntry* fileEntry, FILE* disk, uint8_t* outputBuffer) {
    bool ok = true;
    uint16_t currentCluster = fileEntry->FirstClusterLow; // get first cluster of file
    do {
        uint32_t lba = g_RootDirectoryEnd + (currentCluster - 2) * g_BootSector.SectorsPerCluster; // calculate LBA of cluster
        ok = ok && readSectors(disk, lba, g_BootSector.SectorsPerCluster, outputBuffer); // read cluster
        outputBuffer += g_BootSector.SectorsPerCluster * g_BootSector.BytesPerSector; // advance output buffer

        uint32_t fatIndex  = currentCluster * 3 / 2; // calculate offset in FAT
        if(currentCluster % 2 == 0 ) {
            currentCluster = (*(uint16_t*)(g_Fat + fatIndex )) & 0x0FFF; // read next cluster from FAT;
        } else {
            currentCluster = (*(uint16_t*)(g_Fat + fatIndex )) >> 4; // read next cluster from FAT;
        }

    } while (ok && currentCluster < 0x0FF8); // repeat until end of file

    return ok;
}


int main( int argc, char** argv) {
    if(argc < 3) {
        printf("Usage: %s <disk image> <file name>\n", argv[0]);
        return -1;
    }

    FILE* disk = fopen(argv[1], "rb+");
    if(!disk) {
        fprintf(stderr, "Could not open disk image %s\n", argv[1]);
        return -1;
    }

    if(!readBootSector(disk)) {
        fprintf(stderr, "Could not read boot sector\n");
        return -2;
    }

    if(!readFat(disk)) {
        fprintf(stderr, "Could not read FAT\n");
        free(g_Fat);
        return -3;
    }
    
    if(!readRootDirectory(disk)) {
        fprintf(stderr, "Could not read root directory\n");
        free(g_Fat);
        free(g_RootDirectory);
        return -4;
    }

    DirectoryEntry* entry = findFile(argv[2]);

    if(!entry) {
        fprintf(stderr, "Could not find file %s\n", argv[2]);
        free(g_Fat);
        free(g_RootDirectory);
        return -5;
    }

    uint8_t* outputBuffer = (uint8_t*)malloc(entry->Size + g_BootSector.BytesPerSector);
    if(!readFile(entry, disk, outputBuffer)) {
        fprintf(stderr, "Could not read file %s\n", argv[2]);
        free(g_Fat);
        free(g_RootDirectory);
        free(outputBuffer);
        return -6;
    }

    for(size_t i=0; i < entry->Size; i++) {
        if(isprint(outputBuffer[i])) {
            fputc(outputBuffer[i], stdout);
        } else {
            printf("<%02x>", outputBuffer[i]);
        }
    }

    printf("\n");

    free(g_Fat);
    free(g_RootDirectory);
    return 0;
}