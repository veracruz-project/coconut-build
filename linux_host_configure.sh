cd linux_host/ && \
cp /host_config .config && \
./scripts/config --set-str LOCALVERSION "snp-host" && \
yes "" | make -j 10 olddefconfig