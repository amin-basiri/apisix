start=$(date +%s%N)


# Code Here
curl -i -X POST "http://127.0.0.1:9080/manage_redis_numbers?type=file" -H "Host: example.com" -F msisdns=@numbers_2.csv 
###########


end=$(date +%s%N)
echo "\n\nElapsed Time: $(($end-$start)) ns"
