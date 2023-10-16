start=$(date +%s%N)


# Code Here
curl -i -X POST "http://127.0.0.1:9080/del_number_file" -H "Host: example.com" -F msisdns=@numbers.csv 
###########


end=$(date +%s%N)
echo "\n\nElapsed Time: $(($end-$start)) ns"
