#include <stdio.h>
#include <cuda_runtime.h>

#define N 1024
#define TILE 8

__global__ void gemm_tiled(float *A, float *B, float *C, int n) {
    __shared__ float sA[TILE][TILE];
    __shared__ float sB[TILE][TILE];

    int row = blockIdx.y * TILE + threadIdx.y;
    int col = blockIdx.x * TILE + threadIdx.x;
    float sum = 0.0f;

    /* Use (n + TILE - 1) / TILE so the loop covers all tiles even when
       n is not divisible by TILE. Out-of-bounds threads load 0.0f so
       they contribute nothing to the dot product but the kernel stays
       correct for arbitrary n. */
    int num_tiles = (n + TILE - 1) / TILE;
    for (int t = 0; t < num_tiles; t++) {
        int a_col = t * TILE + threadIdx.x;
        int b_row = t * TILE + threadIdx.y;

        sA[threadIdx.y][threadIdx.x] = (row < n && a_col < n)
                                        ? A[row * n + a_col] : 0.0f;
        sB[threadIdx.y][threadIdx.x] = (b_row < n && col < n)
                                        ? B[b_row * n + col] : 0.0f;
        __syncthreads();

        for (int k = 0; k < TILE; k++)
            sum += sA[threadIdx.y][k] * sB[k][threadIdx.x];
        __syncthreads();
    }

    if (row < n && col < n)
        C[row * n + col] = sum;
}

int main() {
    int size = N * N * sizeof(float);
    float *h_A = (float*)malloc(size);
    float *h_B = (float*)malloc(size);
    float *h_C = (float*)malloc(size);

    for (int i = 0; i < N*N; i++) {
        h_A[i] = 1.0f;
        h_B[i] = 1.0f;
    }

    float *d_A, *d_B, *d_C;
    cudaMalloc(&d_A, size);
    cudaMalloc(&d_B, size);
    cudaMalloc(&d_C, size);

    cudaMemcpy(d_A, h_A, size, cudaMemcpyHostToDevice);
    cudaMemcpy(d_B, h_B, size, cudaMemcpyHostToDevice);

    dim3 threads(TILE, TILE);
    dim3 blocks((N + TILE - 1) / TILE, (N + TILE - 1) / TILE);

    /* Warm-up run */
    gemm_tiled<<<blocks, threads>>>(d_A, d_B, d_C, N);
    cudaDeviceSynchronize();

    /* Timed run */
    cudaEvent_t start, stop;
    cudaEventCreate(&start);
    cudaEventCreate(&stop);
    cudaEventRecord(start);

    gemm_tiled<<<blocks, threads>>>(d_A, d_B, d_C, N);

    cudaEventRecord(stop);
    cudaEventSynchronize(stop);
    float ms = 0;
    cudaEventElapsedTime(&ms, start, stop);

    double flops  = 2.0 * N * N * N;
    double gflops = flops / (ms / 1000.0) / 1e9;

    printf("Tiled GEMM: %.3f ms, %.2f GFLOP/s\n", ms, gflops);

    cudaMemcpy(h_C, d_C, size, cudaMemcpyDeviceToHost);
    printf("Correctness check C[0][0] = %.1f (expected %d)\n", h_C[0], N);

    cudaFree(d_A); cudaFree(d_B); cudaFree(d_C);
    free(h_A); free(h_B); free(h_C);
    return 0;
}
