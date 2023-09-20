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
    uint8_t bdb_oem[8]; // OEM name and version
    uint16_t dbd_bytes; // bytes per sector
    uint8_t dbd_sectors;    // sectors per cluster
    uint16_t dbd_reserved;  // reserved sectors
    uint8_t dbd_fats;    // number of FATs
    uint16_t dbd_root_entries; // number of root directory entries
    uint16_t dbd_sectors_small; // number of sectors (small)
    uint8_t dbd_media; // media descriptor
    uint16_t dbd_sectors_per_fat; // sectors per FAT
    uint16_t dbd_sectors_per_track; // sectors per track
    uint16_t dbd_heads; // number of heads
    uint32_t dbd_hidden; // hidden sectors
    uint32_t dbd_sectors_large; // number of sectors (large)

    uint8_t ebr_drive; // drive number
    uint8_t ebr_reserved; // reserved
    uint8_t ebr_signature; // signature
    uint32_t ebr_volume_id; // volume ID
    uint8_t ebr_volume_label[11]; // volume label
    uint8_t ebr_filesystem[8]; // filesystem type
} __attribute__((packed)) BootSector;

typedef struct {
    uint8_t name[11]; // file name
    uint8_t attributes; // file attributes
    uint8_t reserved;  // reserved
    uint8_t creation_time_ms; // creation time (milliseconds)
    uint16_t creation_time; // creation time
    uint16_t creation_date; // creation date
    uint16_t last_access_date; // last access date
    uint16_t first_cluster_high; // first cluster (high word)
    uint16_t last_modification_time; // last modification time
    uint16_t last_modification_date; // last modification date
    uint16_t first_cluster_low; // first cluster (low word)
    uint32_t file_size; // file size

} __attribute__((packed)) DirectoryEntry;

BootSector bootSector; // boot sector
uint8_t* fat1 = NULL; // FAT
DirectoryEntry* rootDirectory = NULL; // root directory
uint32_t rootDirectoryEnd; // end of root directory

bool readBootSector(FILE* disk) { // read boot sector
    return fread(&bootSector, sizeof(bootSector), 1, disk) > 0; // read boot sector
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

    rootDirectoryEnd = lba + sectors; // calculate end of root directory
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

bool readFile(DirectoryEntry* fileEntry, FILE* disk, uint8_t* outputBuffer) {
    bool ok = true;
    uint16_t currentCluster = fileEntry->first_cluster_low; // get first cluster of file
    do {
        uint32_t lba = rootDirectoryEnd + (currentCluster - 2) * bootSector.dbd_sectors; // calculate LBA of cluster
        ok = ok && readSectors(disk, lba, bootSector.dbd_sectors_per_fat, outputBuffer); // read cluster
        outputBuffer += bootSector.dbd_sectors_per_fat * bootSector.dbd_bytes; // advance output buffer

        uint32_t fatOffset = currentCluster * 3 / 2; // calculate offset in FAT
        if(currentCluster % 2 == 0 ) {
            currentCluster = (*(uint16_t*)(fat1 + fatOffset)) & 0x0FFF; // read next cluster from FAT;
        } else {
            currentCluster = (*(uint16_t*)(fat1 + fatOffset)) >> 4; // read next cluster from FAT;
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

    uint8_t* outputBuffer = (uint8_t*)malloc(entry->file_size + bootSector.dbd_bytes);
    if(!readFile(entry, disk, outputBuffer)) {
        fprintf(stderr, "Could not read file %s\n", argv[2]);
        free(fat1);
        free(rootDirectory);
        free(outputBuffer);
        return -6;
    }

    for(size_t i=0; i < entry->file_size; i++) {
        if(isprint(outputBuffer[i])) {
            fputc(outputBuffer[i], stdout);
        } else {
            printf("<%02x>", outputBuffer[i]);
        }
    }

    printf("\n");

    free(fat1);
    free(rootDirectory);
    return 0;
}