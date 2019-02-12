#import <Foundation/Foundation.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

#define APPNAME "irm"

int usage(void) {
    puts("usage: " APPNAME " [-Rrv] file ...");
    return EXIT_FAILURE;
}

bool recursive, verbose;
int exitcode = EXIT_SUCCESS;

NSStringEncoding systemEncoding;
NSFileManager *fileManager;

void evict(const char *path, NSURL *url) {
    @autoreleasepool {
        NSString *pathString = [NSString stringWithCString:path encoding:systemEncoding];
        NSError *error = nil;
        BOOL directory;
        if (![fileManager fileExistsAtPath:pathString isDirectory:&directory]) {
            return;
        }
        if (recursive && directory) {
            NSArray<NSURLResourceKey> *properties = @[NSURLIsDirectoryKey, NSURLIsUbiquitousItemKey];
            NSArray<NSURL *> *urls = [fileManager contentsOfDirectoryAtURL:url includingPropertiesForKeys:properties options:kNilOptions error:&error];
            if (error) {
                NSLog(@"%@", error);
                return;
            }
            for (NSURL *url in urls) {
                char apath[PATH_MAX] = {'\0'};
                sprintf(apath, "%s/%s", path, [[url lastPathComponent] cStringUsingEncoding:systemEncoding]);
                evict(apath, url);
            }
        }
        [fileManager evictUbiquitousItemAtURL:url error:&error];
        if (error)
            NSLog(@"%@", error);
        else if (verbose)
            puts(path);
    }
}

int main(int argc, char *argv[]) {
    char optchar;
    while ((optchar = getopt(argc, argv, "Rrv")) != -1) {
        switch (optchar) {
            case 'R':
            case 'r':
                recursive = true;
                break;
            case 'v':
                verbose = true;
                break;
            default:
                return usage();
        }
    }
    if (optind >= argc)
        return usage();
    @autoreleasepool {
        systemEncoding = CFStringConvertEncodingToNSStringEncoding(CFStringGetSystemEncoding());
        fileManager = [NSFileManager defaultManager];
        for (const char *arg; optind < argc; optind++) {
            arg = argv[optind];
            NSString *path = [NSString stringWithCString:arg encoding:systemEncoding];
            if (!(path && [path length])) {
                continue;
            }
            NSURL *url = [NSURL fileURLWithPath:path];
            if (![fileManager fileExistsAtPath:path]) {
                NSLog(@"%s: No such file or directory", arg);
                exitcode = EXIT_FAILURE;
                continue;
            }
            if (![fileManager isUbiquitousItemAtURL:url]) {
                NSLog(@"%s: is not in iCloud", arg);
                exitcode = EXIT_FAILURE;
                continue;
            }
            evict(arg, url);
        }
    }
    return exitcode;
}
