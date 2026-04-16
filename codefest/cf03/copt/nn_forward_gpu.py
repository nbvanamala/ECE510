import torch
import sys

# Step 1: Detect GPU
if not torch.cuda.is_available():
    print("No CUDA GPU found. Exiting.")
    sys.exit(1)

device = torch.device("cuda")
print(f"Using device: {torch.cuda.get_device_name(0)}")

# Step 2: Define the network
model = torch.nn.Sequential(
    torch.nn.Linear(4, 5),
    torch.nn.ReLU(),
    torch.nn.Linear(5, 1)
)
model.to(device)
print(f"Model loaded on GPU: {next(model.parameters()).device}")

# Step 3: Generate random input batch
x = torch.randn(16, 4).to(device)

# Step 4: Run forward pass
output = model(x)

# Step 5: Print results
print(f"Output shape: {output.shape}")
print(f"Output device: {output.device}")
