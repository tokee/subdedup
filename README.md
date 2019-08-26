# subdedup
Folder oriented de-duplication scripts

## Requirements
 * bash
 * find
 * md5sum

## Purpose
Locate folders with the same content, prioritized by the largest folder structures first, where largest means those with the most files.

## Usage
Run
`./subdedup.sh <folder>`
and wait.

## Status
Working first version. Slow, as it MD5-sums everything.
