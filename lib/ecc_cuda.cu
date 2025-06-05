#include <cuda_runtime.h>
#include <assert.h>
#include <stdio.h>

#include "../endian_utils.h"

typedef unsigned long long u64;
typedef unsigned int u32;
typedef unsigned char u8;
typedef u64 fe[4];

typedef struct pe {
  fe x, y, z;
} pe;

static_assert(IS_LITTLE_ENDIAN, "CUDA code requires little-endian");
static_assert(sizeof(fe)==32, "fe size");
static_assert(sizeof(pe)==96, "pe size");

#define INLINE __device__ __host__ inline __attribute__((always_inline))

__device__ __constant__ fe d_FE_P; // prime modulus loaded at runtime

static const fe FE_P_HOST = {0xfffffffefffffc2fULL, 0xffffffffffffffffULL,
                             0xffffffffffffffffULL, 0xffffffffffffffffULL};

INLINE u64 addc64(u64 x, u64 y, u64 ci, u64 *co) {
  unsigned __int128 t = (unsigned __int128)x + y + ci;
  *co = (u64)(t >> 64);
  return (u64)t;
}

INLINE u64 subc64(u64 x, u64 y, u64 ci, u64 *co) {
  u64 tmp = y + ci;
  *co = x < tmp;
  return x - tmp;
}

INLINE u64 umul128(u64 a, u64 b, u64 *hi) {
  unsigned __int128 t = (unsigned __int128)a * b;
  *hi = (u64)(t >> 64);
  return (u64)t;
}

INLINE void fe_clone(fe r, const fe a) { for(int i=0;i<4;i++) r[i]=a[i]; }
INLINE void fe_set64(fe r, u64 a) { r[0]=a; r[1]=r[2]=r[3]=0; }
INLINE int fe_cmp(const fe a, const fe b) {
  for(int i=3;i>=0;--i){ if(a[i]!=b[i]) return a[i]>b[i]?1:-1; }
  return 0;
}

INLINE void pe_clone(pe *r, const pe *a){
  // why: ensure struct copy works on host and device
  for(int i=0;i<4;i++){ r->x[i]=a->x[i]; r->y[i]=a->y[i]; r->z[i]=a->z[i]; }
}

INLINE void fe_mul_scalar(u64 r[5], const fe a, u64 b){
  u64 h1,h2,c=0; r[0]=umul128(a[0],b,&h1);
  r[1]=addc64(umul128(a[1],b,&h2),h1,c,&c);
  r[2]=addc64(umul128(a[2],b,&h1),h2,c,&c);
  r[3]=addc64(umul128(a[3],b,&h2),h1,c,&c);
  r[4]=addc64(0,h2,c,&c);
}

INLINE void fe_modp_add(fe r, const fe a, const fe b){
  u64 c=0; r[0]=addc64(a[0],b[0],c,&c); r[1]=addc64(a[1],b[1],c,&c);
  r[2]=addc64(a[2],b[2],c,&c); r[3]=addc64(a[3],b[3],c,&c);
  if(c){ r[0]=subc64(r[0],d_FE_P[0],0,&c); r[1]=subc64(r[1],d_FE_P[1],c,&c);
         r[2]=subc64(r[2],d_FE_P[2],c,&c); r[3]=subc64(r[3],d_FE_P[3],c,&c); }
}

INLINE void fe_modp_sub(fe r, const fe a, const fe b){
  u64 c=0; r[0]=subc64(a[0],b[0],c,&c); r[1]=subc64(a[1],b[1],c,&c);
  r[2]=subc64(a[2],b[2],c,&c); r[3]=subc64(a[3],b[3],c,&c);
  if(c){ r[0]=addc64(r[0],d_FE_P[0],0,&c); r[1]=addc64(r[1],d_FE_P[1],c,&c);
         r[2]=addc64(r[2],d_FE_P[2],c,&c); r[3]=addc64(r[3],d_FE_P[3],c,&c); }
}

INLINE void fe_modp_mul(fe r, const fe a, const fe b){
  u64 rr[8]={0},tt[5]={0},c=0;
  fe_mul_scalar(rr,a,b[0]);
  fe_mul_scalar(tt,a,b[1]);
  rr[1]=addc64(rr[1],tt[0],c,&c); rr[2]=addc64(rr[2],tt[1],c,&c);
  rr[3]=addc64(rr[3],tt[2],c,&c); rr[4]=addc64(rr[4],tt[3],c,&c);
  rr[5]=addc64(rr[5],tt[4],c,&c);
  fe_mul_scalar(tt,a,b[2]);
  rr[2]=addc64(rr[2],tt[0],c,&c); rr[3]=addc64(rr[3],tt[1],c,&c);
  rr[4]=addc64(rr[4],tt[2],c,&c); rr[5]=addc64(rr[5],tt[3],c,&c);
  rr[6]=addc64(rr[6],tt[4],c,&c);
  fe_mul_scalar(tt,a,b[3]);
  rr[3]=addc64(rr[3],tt[0],c,&c); rr[4]=addc64(rr[4],tt[1],c,&c);
  rr[5]=addc64(rr[5],tt[2],c,&c); rr[6]=addc64(rr[6],tt[3],c,&c);
  rr[7]=addc64(rr[7],tt[4],c,&c);
  fe_mul_scalar(tt,rr+4,0x1000003D1ULL);
  rr[0]=addc64(rr[0],tt[0],0,&c); rr[1]=addc64(rr[1],tt[1],c,&c);
  rr[2]=addc64(rr[2],tt[2],c,&c); rr[3]=addc64(rr[3],tt[3],c,&c);
  u64 hi,lo; lo=umul128(tt[4]+c,0x1000003D1ULL,&hi);
  r[0]=addc64(rr[0],lo,0,&c); r[1]=addc64(rr[1],hi,c,&c);
  r[2]=addc64(rr[2],0,c,&c); r[3]=addc64(rr[3],0,c,&c);
  if(fe_cmp(r,d_FE_P)>=0) fe_modp_sub(r,r,d_FE_P);
}

INLINE void fe_modp_sqr(fe r, const fe a){
  u64 rr[8]={0},tt[5]={0},c=0,t1,t2,lo,hi;
  rr[0]=umul128(a[0],a[0],&tt[1]);
  tt[3]=umul128(a[0],a[1],&tt[4]);
  tt[3]=addc64(tt[3],tt[3],0,&c); tt[4]=addc64(tt[4],tt[4],c,&c); t1=c;
  tt[3]=addc64(tt[1],tt[3],0,&c); tt[4]=addc64(tt[4],0,c,&c); t1+=c; rr[1]=tt[3];
  tt[0]=umul128(a[0],a[2],&tt[1]); tt[0]=addc64(tt[0],tt[0],0,&c);
  tt[1]=addc64(tt[1],tt[1],c,&c); t2=c; lo=umul128(a[1],a[1],&hi);
  tt[0]=addc64(tt[0],lo,0,&c); tt[1]=addc64(tt[1],hi,c,&c); t2+=c;
  tt[0]=addc64(tt[0],tt[4],0,&c); tt[1]=addc64(tt[1],t1,c,&c); t2+=c; rr[2]=tt[0];
  tt[3]=umul128(a[0],a[3],&tt[4]); lo=umul128(a[1],a[2],&hi);
  tt[3]=addc64(tt[3],lo,0,&c); tt[4]=addc64(tt[4],hi,c,&c); t1=c+c;
  tt[3]=addc64(tt[3],tt[3],0,&c); tt[4]=addc64(tt[4],tt[4],c,&c); t1+=c;
  tt[3]=addc64(tt[1],tt[3],0,&c); tt[4]=addc64(tt[4],t2,c,&c); t1+=c; rr[3]=tt[3];
  tt[0]=umul128(a[1],a[3],&tt[1]); tt[0]=addc64(tt[0],tt[0],0,&c);
  tt[1]=addc64(tt[1],tt[1],c,&c); t2=c; lo=umul128(a[2],a[2],&hi);
  tt[0]=addc64(tt[0],lo,0,&c); tt[1]=addc64(tt[1],hi,c,&c); t2+=c;
  tt[0]=addc64(tt[0],tt[4],0,&c); tt[1]=addc64(tt[1],t1,c,&c); t2+=c; rr[4]=tt[0];
  tt[3]=umul128(a[2],a[3],&tt[4]); tt[3]=addc64(tt[3],tt[3],0,&c);
  tt[4]=addc64(tt[4],tt[4],c,&c); t1=c; tt[3]=addc64(tt[3],tt[1],0,&c);
  tt[4]=addc64(tt[4],t2,c,&c); t1+=c; rr[5]=tt[3];
  tt[0]=umul128(a[3],a[3],&tt[1]); tt[0]=addc64(tt[0],tt[4],0,&c);
  tt[1]=addc64(tt[1],t1,c,&c); rr[6]=tt[0]; rr[7]=tt[1];
  fe_mul_scalar(tt,rr+4,0x1000003D1ULL);
  rr[0]=addc64(rr[0],tt[0],0,&c); rr[1]=addc64(rr[1],tt[1],c,&c);
  rr[2]=addc64(rr[2],tt[2],c,&c); rr[3]=addc64(rr[3],tt[3],c,&c);
  lo=umul128(tt[4]+c,0x1000003D1ULL,&hi);
  r[0]=addc64(rr[0],lo,0,&c); r[1]=addc64(rr[1],hi,c,&c);
  r[2]=addc64(rr[2],0,c,&c); r[3]=addc64(rr[3],0,c,&c);
  if(fe_cmp(r,d_FE_P)>=0) fe_modp_sub(r,r,d_FE_P);
}

INLINE void fe_modp_neg(fe r,const fe a){
  u64 c=0; r[0]=subc64(d_FE_P[0],a[0],c,&c);
  r[1]=subc64(d_FE_P[1],a[1],c,&c); r[2]=subc64(d_FE_P[2],a[2],c,&c);
  r[3]=subc64(d_FE_P[3],a[3],c,&c);
}

INLINE void _ec_jacobi_dbl1(pe *r,const pe *p){
  fe w,s,b,h,t; fe_modp_sqr(t,p->x); fe_modp_add(w,t,t);
  fe_modp_add(w,w,t); fe_modp_mul(s,p->y,p->z); fe_modp_mul(b,p->x,p->y);
  fe_modp_mul(b,b,s); fe_modp_add(b,b,b); fe_modp_add(b,b,b);
  fe_modp_add(t,b,b); fe_modp_sqr(h,w); fe_modp_sub(h,h,t);
  fe_modp_mul(r->x,h,s); fe_modp_add(r->x,r->x,r->x);
  fe_modp_sub(t,b,h); fe_modp_mul(t,w,t); fe_modp_sqr(r->y,p->y);
  fe_modp_sqr(h,s); fe_modp_mul(r->y,r->y,h); fe_modp_add(r->y,r->y,r->y);
  fe_modp_add(r->y,r->y,r->y); fe_modp_add(r->y,r->y,r->y);
  fe_modp_sub(r->y,t,r->y); fe_modp_mul(r->z,h,s); fe_modp_add(r->z,r->z,r->z);
  fe_modp_add(r->z,r->z,r->z); fe_modp_add(r->z,r->z,r->z);
}

INLINE void _ec_jacobi_add1(pe *r,const pe *p,const pe *q){
  fe u2,v2,u,v,w,a,vs,vc; fe_modp_mul(u2,p->y,q->z);
  fe_modp_mul(v2,p->x,q->z); fe_modp_mul(u,q->y,p->z);
  fe_modp_mul(v,q->x,p->z); assert(fe_cmp(v,v2)!=0);
  fe_modp_mul(w,p->z,q->z); fe_modp_sub(u,u,u2); fe_modp_sub(v,v,v2);
  fe_modp_sqr(vs,v); fe_modp_mul(vc,vs,v); fe_modp_mul(vs,vs,v2);
  fe_modp_mul(r->z,vc,w); fe_modp_sqr(a,u); fe_modp_mul(a,a,w);
  fe_modp_add(w,vs,vs); fe_modp_sub(a,a,vc); fe_modp_sub(a,a,w);
  fe_modp_mul(r->x,v,a); fe_modp_sub(a,vs,a); fe_modp_mul(a,a,u);
  fe_modp_mul(u,vc,u2); fe_modp_sub(r->y,a,u);
}

__global__ void mul_kernel(pe *r,const pe *p,const fe k,u32 bits){
  pe t; fe_clone(t.x,p->x); fe_clone(t.y,p->y); fe_clone(t.z,p->z);
  fe_set64(r->x,0); fe_set64(r->y,0); fe_set64(r->z,1);
  for(u32 i=0;i<bits;++i){
    if(k[i/64] & (1ULL<<(i%64))){
      if(r->x[0]==0 && r->y[0]==0) pe_clone(r,&t);
      else _ec_jacobi_add1(r,r,&t);
    }
    _ec_jacobi_dbl1(&t,&t);
  }
}

#define CUDA_CHECK_ERROR() \
  do { cudaError_t e=cudaGetLastError(); \
       if(e!=cudaSuccess){fprintf(stderr,"CUDA %s:%d %s\n",__FILE__,__LINE__,cudaGetErrorString(e));assert(0);} } while(0)

static void ensure_const(){
  static bool init=false; if(!init){
    cudaMemcpyToSymbol(d_FE_P,FE_P_HOST,sizeof(fe)); CUDA_CHECK_ERROR();
    init=true;
  }
}

extern "C" void ec_jacobi_mulrdc_cuda(pe *r,const pe *p,const fe k){
  ensure_const();
  pe *d_r,*d_p; fe *d_k; u32 bits=0; for(int i=3;i>=0;--i){ if(k[i]){ bits=64*i+ (64-__builtin_clzll(k[i])); break; }}
  cudaMalloc(&d_r,sizeof(pe)); CUDA_CHECK_ERROR();
  cudaMalloc(&d_p,sizeof(pe)); CUDA_CHECK_ERROR();
  cudaMalloc(&d_k,sizeof(fe)); CUDA_CHECK_ERROR();
  cudaMemcpy(d_p,p,sizeof(pe),cudaMemcpyHostToDevice); CUDA_CHECK_ERROR();
  cudaMemcpy(d_k,k,sizeof(fe),cudaMemcpyHostToDevice); CUDA_CHECK_ERROR();
  mul_kernel<<<1,1>>>(d_r,d_p,*d_k,bits); CUDA_CHECK_ERROR();
  cudaMemcpy(r,d_r,sizeof(pe),cudaMemcpyDeviceToHost); CUDA_CHECK_ERROR();
  cudaFree(d_r); cudaFree(d_p); cudaFree(d_k); CUDA_CHECK_ERROR();
}
