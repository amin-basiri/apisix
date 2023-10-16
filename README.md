# Separated APIs


### Call Add

```shell
curl -i -X POST "http://127.0.0.1:9080/add_number" -H "Host: example.com" -d '{"number": "9911339329"}' -H 'Content-Type: application/json'
```


### Call Add Batch

```shell
curl -i -X POST "http://127.0.0.1:9080/add_number_batch" -H "Host: example.com" -d '09011337323,09011337324,09011337325' -H 'Content-Type: application/json'
```


### Call Add File

```shell
curl -i -X POST "http://127.0.0.1:9080/add_number_file" -H "Host: example.com" -F numbers=@numbers.csv 
```



### Call Del

```shell
curl -i -X POST "http://127.0.0.1:9080/del_number" -H "Host: example.com" -d '{"number": "9911339329"}' -H 'Content-Type: application/json'
```


### Call Del Batch

```shell
curl -i -X POST "http://127.0.0.1:9080/del_number_batch" -H "Host: example.com" -d '09011337323,09011337324,09011337325' -H 'Content-Type: application/json'
```



### Call Del File

```shell
curl -i -X POST "http://127.0.0.1:9080/del_number_file" -H "Host: example.com" -F numbers=@numbers.csv 
```

----------------------------------------------------------------------------------


# Manage Redis MSISDNs

### Add One MSISDN

```shell
curl -i -X POST "http://127.0.0.1:9080/manage_redis_numbers?type=normal" -H "Host: example.com" -H 'Content-Type: application/json' -d '{"msisdn": "9011337323"}'
```

### Get One MSISDN

```shell
curl -i -X GET "http://127.0.0.1:9080/manage_redis_numbers?type=normal&msisdn=9011337323" -H "Host: example.com"
```


### Delete One MSISDN

```shell
curl -i -X DELETE "http://127.0.0.1:9080/manage_redis_numbers?type=normal&msisdn=9011337323" -H "Host: example.com"
```


### Edit One MSISDN

```shell
curl -i -X PUT "http://127.0.0.1:9080/manage_redis_numbers?type=normal" -H "Host: example.com" -H 'Content-Type: application/json' -d '{"msisdn": "9011337323", "to": "E"}'
```


### Set (add, edit) MSISDN File

```shell
curl -i -X POST "http://127.0.0.1:9080/manage_redis_numbers?type=file" -H "Host: example.com" -F msisdns=@numbers.csv 
```


### Get MSISDN File

```shell
curl -i -X GET "http://127.0.0.1:9080/manage_redis_numbers?type=file" -H "Host: example.com" -F msisdns=@numbers.csv 
```


### Delete MSISDN File

```shell
curl -i -X DELETE "http://127.0.0.1:9080/manage_redis_numbers?type=file" -H "Host: example.com" -F msisdns=@numbers.csv 
```


### Set (add, edit) MSISDN Batch

```shell
curl -i -X POST "http://127.0.0.1:9080/manage_redis_numbers?type=batch" -H "Host: example.com" -H 'Content-Type: application/json' -d '{"9011337323": "H", "9011337324": "E", "9011337325": "H"}'
```


### Get MSISDN Batch

```shell
curl -i -X GET "http://127.0.0.1:9080/manage_redis_numbers?type=batch&msisdns=9011337323,9011337324,9011337325" -H "Host: example.com"
```


### Delete MSISDN Batch

```shell
curl -i -X DELETE "http://127.0.0.1:9080/manage_redis_numbers?type=batch&msisdns=9011337323,9011337324,9011337325" -H "Host: example.com"
```