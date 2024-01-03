#/usr/bin/bash
cd linux_guest && \
./scripts/config --set-str LOCALVERSION "snp-guest" && \
./scripts/config --disable LOCALVERSION_AUTO && \
./scripts/config --enable  EXPERT && \
./scripts/config --enable  DEBUG_INFO && \
./scripts/config --enable  DEBUG_INFO_REDUCED && \
./scripts/config --enable  AMD_MEM_ENCRYPT && \
./scripts/config --disable AMD_MEM_ENCRYPT_ACTIVE_BY_DEFAULT && \
./scripts/config --enable  KVM_AMD_SEV && \
./scripts/config --module  CRYPTO_DEV_CCP_DD && \
./scripts/config --disable SYSTEM_TRUSTED_KEYS && \
./scripts/config --disable SYSTEM_REVOCATION_KEYS && \
./scripts/config --disable MODULE_SIG_KEY && \
./scripts/config --module  SEV_GUEST && \
./scripts/config --disable IOMMU_DEFAULT_PASSTHROUGH && \
./scripts/config --disable PREEMPT_COUNT && \
./scripts/config --disable PREEMPTION && \
./scripts/config --disable PREEMPT_DYNAMIC && \
./scripts/config --disable DEBUG_PREEMPT && \
./scripts/config --enable  CGROUP_MISC && \
./scripts/config --module  X86_CPUID && \
./scripts/config --disable UBSAN && \
yes "" | make -j 10 olddefconfig
