#!/bin/sh
# Automated regression checks for the samefile script.

set -u

tmp_root=${TMPDIR:-/tmp}
suffix=$$
attempt=0

while :; do
  test_dir=$tmp_root/samefile_tests.$suffix.$attempt
  if (umask 077 && mkdir "$test_dir") 2>/dev/null; then
    break
  fi
  attempt=$((attempt + 1))
done

cleanup() {
  if [ -d "$test_dir" ]; then
    rm -rf "$test_dir"
  fi
}

trap 'cleanup' 0 1 2 3 15

identical_a=$test_dir/identical_a.txt
identical_b=$test_dir/identical_b.txt
short_file=$test_dir/different_size_short.txt
long_file=$test_dir/different_size_long.txt
inode_src=$test_dir/inode_original.txt
inode_link=$test_dir/inode_hardlink.txt

printf 'same content\n' > "$identical_a"
printf 'same content\n' > "$identical_b"

printf 'short\n' > "$short_file"
printf 'this is a longer file\nwith two lines\n' > "$long_file"

printf 'inode sample\n' > "$inode_src"
ln "$inode_src" "$inode_link"

cd "$test_dir"

pass=0
fail=0

print_separator() {
  printf '\n'
}

run_case() {
  name=$1
  expected_exit=$2
  expected_message=$3
  file1=$4
  file2=$5

  print_separator
  printf '[%s]\n' "$name"
  printf '$ samefile --verbose %s %s\n' "$file1" "$file2"

  output=$(samefile --verbose "$file1" "$file2" 2>&1)
  status=$?

  printf '%s\n' "$output"
  printf 'exit:%s\n' "$status"

  if [ "$status" -eq "$expected_exit" ] && [ "$output" = "$expected_message" ]; then
    printf 'PASS %s\n' "$name"
    pass=$((pass + 1))
  else
    printf 'FAIL %s\n' "$name"
    fail=$((fail + 1))
  fi
}

size_short=$(wc -c < "$short_file")
size_long=$(wc -c < "$long_file")
size_message=$(printf 'different: sizes differ (%s vs %s bytes)' "$size_short" "$size_long")

run_case "Identical files" 0 "same: byte-for-byte identical" \
  "identical_a.txt" "identical_b.txt"

run_case "Different sizes" 1 "$size_message" \
  "different_size_short.txt" "different_size_long.txt"

run_case "Same inode" 0 "same: both paths refer to the same inode" \
  "inode_original.txt" "inode_hardlink.txt"

run_case "Missing file" 2 "samefile: error: missing_file.txt does not exist" \
  "missing_file.txt" "identical_a.txt"

print_separator
printf 'Summary: %d passed, %d failed\n' "$pass" "$fail"

if [ "$fail" -eq 0 ]; then
  exit 0
fi

exit 1
