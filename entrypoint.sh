#!/usr/bin/bash

system_file="/data/work/system_download.txt"
es_array=($(cat ${system_file} | grep elasticsearch_ip | awk -F '|' '{for(i=2; i<=NF; i++) print $i}'))
len_array=${#es_array[@]}

es_yml_path=$(find /etc -name elasticsearch.yml)

sed -i '/^[^#]/d' ${es_yml_path}
# elasticsearch.yml-start system_download.txt 참조하여 동적 setup
es_yml=$(awk '/\[elasticsearch.yml-start\]/{flag=1; next} /\[elasticsearch.yml-end\]/{flag=0} flag' ${system_file})
es_data_path=''
while IFS= read -r es_yml_low;
do
        es_env_name=$(echo $es_yml_low | awk -F '|' '{print $1}' | sed 's/[][]//g')
        es_env_value=$(echo $es_yml_low | awk -F '|' '{print $2}')

	if [ "${es_env_name}" == "path.data" ]; then
		es_data_path=${es_env_value}
	fi
	# # 포함되어 있거나 es_env_name으로 시작하는 라인 수정 (없으면 추가 .. ㅎㅎ)
	if grep -q ${es_env_name} ${es_yml_path}; then
        	sed -i "/^\(#\)\?${es_env_name}/s|^#\?\(${es_env_name}\).*|${es_env_name}: ${es_env_value}|" "${es_yml_path}"
	else
		echo "${es_env_name}: ${es_env_value}" >> ${es_yml_path}
	fi
done <<< $es_yml

jvm_options_path=$(find /etc -name jvm.options)
# jva.options-start system_download.txt 참조하여 동적 setup
jvm_options=$(awk '/\[jvm.options-start\]/{flag=1; next} /\[jvm.options-end\]/{flag=0} flag' ${system_file})
while IFS= read -r jvm_options_low;
do
        jvm_options_name=$(echo $jvm_options_low | awk -F '|' '{print $1}' | sed 's/[][]//g')
        jvm_options_value=$(echo $jvm_options_low | awk -F '|' '{print $2}')
	# jvm.options 파일에서 해당 옵션을 찾고, 값을 바꿔줌
    	sed -i "/-${jvm_options_name}.*g/c\\${jvm_options_value}" ${jvm_options_path}
done <<< $jvm_options

for ((i=0; i<len_array; i++));
do
	current_ip=${es_array[$i]}
	scp ${es_yml_path} root@${current_ip}:${es_yml_path}
	scp ${jvm_options_path} root@${current_ip}:${jvm_options_path}

	# 엘라스틱 데이터 디렉토리
	ssh ${current_ip} "if [ -d '${es_data_path}' ]; then rm -rf ${es_data_path}; fi; mkdir -p ${es_data_path}"
	ssh ${current_ip} "chown -R elasticsearch:elasticsearch ${es_data_path}"
done
