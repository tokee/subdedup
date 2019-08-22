# subdedup
Folder oriented de-duplication scripts

## Requirements
 * bash

## Purpose
Locate folders with the same content, prioritized by the largest folder structures first.

## Idea
 * Calculate checksums for all files
 * Calculate checksums for all folders, where a folder checksum is created by concatinating checksums for all contained elements (files and sub folders) and calculating a checksum for that
   * Extract the pairs for folders
   * Sort by checksum
   * Remove pairs with unique checksums
   * Group by folder-depth
   * Iterate all pairs, group by group, starting with lowest folder depth
     * If a duplicate is found, write out all instances

## Status
Idea phase only.
