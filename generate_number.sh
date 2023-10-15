hexdump -v -e '5/1 "%02x""\n"' /dev/urandom |
  awk -v OFS=',' '
    { print 9int(NR * 32419768 * rand()), " H" }' |
  head -n "$1" > numbers.csv