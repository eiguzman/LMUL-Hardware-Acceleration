import struct
import numpy as np

def bf16_hex_to_float(bf16_hex):
    """Convert a 16-bit BF16 hex string to float32."""
    # bf16 stored in top 16 bits of float32
    bf16_int = int(bf16_hex, 16)
    # Shift to top 16 bits of float32
    bits = bf16_int << 16
    # Pack as 32-bit unsigned int
    s = struct.pack('>I', bits)
    return struct.unpack('>f', s)[0]

# Load results
results = []
with open('results.csv', 'r') as f:
    for line in f:
        line = line.strip()
        if not line:
            continue
        idx_str, val_str = line.split(',')
        val = bf16_hex_to_float(val_str)
        results.append(val)

# Load ground truth labels (modify as needed)
# For demonstration, assume labels are stored in a list
# Alternatively, you can load from a file if labels are known
# Example: ground_truth_labels = [3, 0, 4, 7, 1]
# For now, random labels (replace with actual labels if available)
ground_truth_labels = [0]*len(results)  # replace with actual labels if known

# For demonstration, we assume labels are known:
# For a real scenario, load labels from a file or embed them in your Python code
# Example: load from a file 'labels.txt' with lines: index,label
# with open('labels.txt', 'r') as lf:
#     ground_truth_labels = [int(line.strip()) for line in lf]

# Classify based on max activation
predicted_labels = np.argmax(results)

print("Predicted label:", predicted_labels)

# For evaluation, compare with ground truth
# If actual labels are available:
correct = 0
total = len(results)

# Example: if you have ground truth labels
# for i in range(total):
#     pred = np.argmax(results[i])
#     if pred == ground_truth_labels[i]:
#         correct += 1

# Since we don't have true labels here, just output predicted
print(f"Predicted class: {predicted_labels}")
# If labels are available, compute accuracy
# print(f"Accuracy: {correct/total*100:.2f}%")
