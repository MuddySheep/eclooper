#ifndef NVCC_ARCH_NUM
#error "NVCC_ARCH_NUM missing"
#endif
int main(){ return (NVCC_ARCH_NUM>=30)?0:1; }
