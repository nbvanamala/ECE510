import sys
import torch
import torch.nn as nn

# 1. Detect CUDA GPU
if not torch.cuda.is_available():
    print("No CUDA-capable GPU found. Exiting.")
    sys.exit(1)

device = torch.device("cuda")
print(f"Using device: {torch.cuda.get_device_name(0)}")

# 2. Define the network: Linear(4->5) -> ReLU -> Linear(5->1)
model = nn.Sequential(
    nn.Linear(4, 5),
    nn.ReLU(),
    nn.Linear(5, 1)
)
model.to(device)

# 3. Generate random input batch [16, 4], run forward pass
x = torch.randn(16, 4).to(device)
output = model(x)

print(f"Output tensor shape: {output.shape}")
print(f"Output device: {output.device}")
