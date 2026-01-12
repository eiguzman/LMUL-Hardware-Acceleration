import torch
import torchvision
import torchvision.transforms as transforms
import numpy as np
import struct

# Function to convert float32 to BF16 (binary16) format
def float32_to_bf16(value):
    # Pack float as uint32
    f = np.float32(value)
    bits = np.frombuffer(f.tobytes(), dtype=np.uint32)[0]
    # Take the top 16 bits
    bf16 = bits >> 16
    return bf16

# Save function for images
def save_image_bf16(image_tensor, filename):
    # image_tensor: 28x28 tensor normalized [0,1]
    flattened = image_tensor.flatten()
    bf16_array = [float32_to_bf16(val) for val in flattened]
    with open(filename, 'wb') as f:
        for val in bf16_array:
            f.write(struct.pack('>H', val))  # big-endian 16-bit

# Save function for weights
def save_weights_bf16(weights, filename):
    # weights: M x N tensor
    bf16_array = [float32_to_bf16(w) for w in weights.flatten()]
    with open(filename, 'wb') as f:
        for val in bf16_array:
            f.write(struct.pack('>H', val))

# Parameters
N = 28
M = 10  # number of classes
NUM_SAMPLES = 5  # For testing; increase as needed

# Load MNIST dataset
transform = transforms.Compose([
    transforms.ToTensor(),  # converts to [0,1]
])

dataset = torchvision.datasets.MNIST(root='./data', train=False, download=True, transform=transform)

# Generate random weights for the final layer (or load pretrained weights)
# For real application, load your trained model weights
np.random.seed(42)
weights_np = np.random.randn(M, N*N).astype(np.float32) * 0.1  # small random weights

# Save weights once
save_weights_bf16(torch.tensor(weights_np), 'weights.bin')

# Generate input images and save
for i in range(NUM_SAMPLES):
    img, label = dataset[i]
    filename = f'input_image_{i}.bin'
    save_image_bf16(img, filename)
    print(f'Saved image {i} with label {label} to {filename}')

print('Finished generating input images and weights.')
