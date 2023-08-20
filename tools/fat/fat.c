#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

typedef uint8_t bool;
#define true 1
#define false 0

typedef struct
{
    uint8_t BootJumpInstruction[3];
    uint8_t bdb_oem[8];
    uint16_t dbd_bytes;
    uint8_t dbd_sectors;
    uint16_t dbd_reserved;
    uint8_t dbd_fats;
    uint16_t dbd_root_entries;
    uint16_t dbd_sectors_small;
    uint8_t dbd_media;
    uint16_t dbd_sectors_per_fat;
    uint16_t dbd_sectors_per_track;
    uint16_t dbd_heads;
    uint32_t dbd_hidden;
    uint32_t dbd_sectors_large;

    uint8_t ebr_drive;
    uint8_t ebr_reserved;
    uint8_t ebr_signature;
    uint32_t ebr_volume_id;
    uint8_t ebr_volume_label[11];
    uint8_t ebr_filesystem[8];
} __attribute__((packed)) BootSector;

typedef struct {
    uint8_t name[11];
    uint8_t attributes;
    uint8_t reserved;
    uint8_t creation_time_ms;
    uint16_t creation_time;
    uint16_t creation_date;
    uint16_t last_access_date;
    uint16_t first_cluster_high;
    uint16_t last_modification_time;
    uint16_t last_modification_date;
    uint16_t first_cluster_low;
    uint32_t file_size;

} __attribute__((packed)) DirectoryEntry;

BootSector bootSector;
uint8_t* fat1 = NULL;
DirectoryEntry* rootDirectory = NULL;

bool readBootSector(FILE* disk) { // read boot sector
    return fread(&bootSector, sizeof(BootSector), 1, disk) > 0; // read boot sector
}


bool readSectors(FILE* disk, uint32_t lba, uint32_t count, void* buffer) { // read sectors
    bool ok = true;
    ok = ok && (fseek(disk, lba * bootSector.dbd_bytes, SEEK_SET) == 0); // seek to the beginning of the sector
    ok = ok && (fread(buffer, bootSector.dbd_bytes, count, disk) == count); // read the sector
    return ok;
}

bool readFat(FILE* disk) {
    fat1 = (uint8_t*)malloc(bootSector.dbd_sectors_per_fat * bootSector.dbd_bytes); // allocate memory for FAT
    return readSectors(disk, bootSector.dbd_reserved, bootSector.dbd_sectors_per_fat, fat1); // read FAT
}

bool readRootDirectory(FILE* disk) {
    uint32_t lba = bootSector.dbd_reserved + bootSector.dbd_sectors_per_fat * bootSector.dbd_fats; // calculate LBA of root directory
    uint32_t size = bootSector.dbd_root_entries * sizeof(DirectoryEntry); // calculate size of root directory
    uint32_t sectors = (size / bootSector.dbd_bytes); // calculate number of sectors
    
    if(size % bootSector.dbd_bytes > 0) { // if there is a remainder -> round up
        sectors++;
    }

    rootDirectory = (DirectoryEntry*)malloc(sectors * bootSector.dbd_bytes); // allocate memory for root directory
    return readSectors(disk, lba, sectors, rootDirectory); // read root directory
}

DirectoryEntry* findFile(const char* name) {
    for(uint32_t i = 0; i < bootSector.dbd_root_entries; i++) { // iterate through root directory
        if(memcmp(name, rootDirectory[i].name, 11) == 0) { // compare file name
            return &rootDirectory[i]; // return pointer to directory entry
        }
    }

    return NULL;
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
        free(fat1);
        return -3;
    }
    
    if(!readRootDirectory(disk)) {
        fprintf(stderr, "Could not read root directory\n");
        free(fat1);
        free(rootDirectory);
        return -4;
    }

    DirectoryEntry* entry = findFile(argv[2]);

    if(!entry) {
        fprintf(stderr, "Could not find file %s\n", argv[2]);
        free(fat1);
        free(rootDirectory);
        return -5;
    }

    free(fat1);
    free(rootDirectory);
    return 0;
}