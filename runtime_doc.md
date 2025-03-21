# ONNX Runtime Installation and Inference Guide

This documentation guides you through the process of setting up a Python virtual environment, installing ONNX Runtime, and running inference with YOLO ONNX models, with clearly separated components.

> **Additional Resources:**
> - Official ONNX Runtime Documentation: [https://onnxruntime.ai/docs/](https://onnxruntime.ai/docs/)
> - Microsoft Olive for Model Fine-tuning and Optimization: [https://github.com/microsoft/Olive](https://github.com/microsoft/Olive)

## 1. Setting Up the Virtual Environment

Creating a virtual environment helps isolate dependencies for your project:

```bash
# Install virtualenv if not already installed
pip install virtualenv

# Create a new virtual environment
python -m virtualenv venv

# Activate the virtual environment
# On Linux/macOS:
source venv/bin/activate
# On Windows:
# venv\Scripts\activate
```

## 2. Installing ONNX Runtime and Dependencies

Once your virtual environment is activated, install the ONNX Runtime wheel file and Pillow-SIMD for faster image processing:


```bash
# Navigate to the directory containing the .whl file
cd /path/to/wheel/directory

# Install the wheel file
pip install onnxruntime-1.20.1-cp310-cp310-linux_x86_64.whl

# Install Pillow-SIMD for faster image processing
pip install pillow-simd

# Install other required dependencies
pip install numpy
```

## 3. Verifying the Installation

Verify that ONNX Runtime is correctly installed:

```python
import onnxruntime as ort

# Check available execution providers
print("Available Execution Providers:", ort.get_available_providers())

# If using custom execution providers like Barq, verify it's available
if "BarqExecutionProvider" in ort.get_available_providers():
    print("Barq Execution Provider is correctly installed!")
else:
    print("Warning: Barq EP not found among available providers")
```

## 4. YOLO Inference Process

The inference process is divided into three separate components:

### 4.1 Preprocessing Component

The preprocessing component handles image preparation for YOLO models:

```python
import numpy as np
from PIL import Image  # This will use Pillow-SIMD if installed correctly

def preprocess_image_yolo(image_path, target_height=640, target_width=640):
    """
    Preprocess an image for YOLOv8 model inference.
    
    Args:
        image_path (str): Path to the input image
        target_height (int): Target height for resizing
        target_width (int): Target width for resizing
        
    Returns:
        numpy.ndarray: Preprocessed image data ready for inference
    """
    # 1. Load the image
    image = Image.open(image_path).convert("RGB")
    
    # 2. Resize the image to target dimensions (if needed)
    image = image.resize((target_width, target_height), Image.BILINEAR)
    
    # 3. Convert to numpy array with float32 dtype
    img_data = np.array(image).astype(np.float32)
    
    # 4. Normalize pixel values to [0,1]
    img_data = img_data / 255.0
    
    # 5. Apply mean and standard deviation normalization
    mean = np.array([0.485, 0.456, 0.406], dtype=np.float32)
    std = np.array([0.229, 0.224, 0.225], dtype=np.float32)
    img_data = (img_data - mean[None, None, :]) / std[None, None, :]
    
    # 6. Transpose from HWC to CHW format (if needed)
    # From (height, width, channels) to (channels, height, width, our accelerator is NCHW input for now)
    img_data = img_data.transpose(2, 0, 1)
    
    # 7. Add batch dimension (if you will process multiple batches at once)
    img_data = np.expand_dims(img_data, axis=0)
    
    return img_data
```

### 4.2 Inference Component

The inference component focuses solely on running the model, without any timing or additional processing:

```python
import onnxruntime as ort

def create_inference_session(model_path):
    """
    Create an ONNX Runtime inference session using BarqExecutionProvider.
    
    Args:
        model_path (str): Path to the ONNX model
        
    Returns:
        onnxruntime.InferenceSession: Session for running inference
    """
    # Configure session options
    session_options = ort.SessionOptions()
    session_options.graph_optimization_level = ort.GraphOptimizationLevel.ORT_ENABLE_ALL
    
    # Use BarqExecutionProvider exclusively
    providers = ["BarqExecutionProvider"]
    
    # Create session
    session = ort.InferenceSession(
        model_path,
        sess_options=session_options,
        providers=providers
    )
    
    return session

def run_inference(session, input_data):
    """
    Run inference with the provided session and input data.
    Pure inference function without timing or logging.
    
    Args:
        session (onnxruntime.InferenceSession): ONNX Runtime session
        input_data (numpy.ndarray): Preprocessed input data
        
    Returns:
        list: Model outputs
    """
    # Get input and output names
    input_name = session.get_inputs()[0].name
    output_names = [output.name for output in session.get_outputs()]
    
    # Run inference
    outputs = session.run(output_names, {input_name: input_data})
    
    return outputs
```

### 4.3 Postprocessing Component

The postprocessing component handles YOLO model outputs:

```python
import numpy as np

def postprocess_yolo_output(outputs, conf_threshold=0.25, iou_threshold=0.45, labels_path=None):
    """
    Process YOLOv8 model outputs to extract detections.
    
    Args:
        outputs (list): Model outputs from ONNX Runtime
        conf_threshold (float): Confidence threshold for detections
        iou_threshold (float): IOU threshold for non-maximum suppression
        labels_path (str, optional): Path to labels file
        
    Returns:
        list: List of detection results
    """
    # Load labels if provided
    labels = []
    if labels_path:
        with open(labels_path, "r") as f:
            labels = [line.strip() for line in f]
    
    # Get the detection output (in YOLOv8, it's typically the first output)
    detection_output = outputs[0]
    
    # Extract detections above threshold
    results = []
    
    # YOLOv8 output format is [batch, num_detections, 4+1+num_classes]
    # where 4 is for bbox (x, y, w, h), 1 is for confidence, and rest are class probabilities
    for i in range(detection_output.shape[1]):
        # Extract confidence
        confidence = detection_output[0, i, 4]
        
        if confidence >= conf_threshold:
            # Get class scores
            class_scores = detection_output[0, i, 5:]
            class_id = np.argmax(class_scores)
            class_score = class_scores[class_id]
            
            # Combine confidence with class score
            confidence = float(confidence * class_score)
            
            if confidence >= conf_threshold:
                # Get coordinates (YOLOv8 outputs center x, center y, width, height)
                x, y, w, h = detection_output[0, i, :4]
                
                # Convert to [x1, y1, x2, y2] format (top-left, bottom-right corners)
                x1 = float(x - w/2)
                y1 = float(y - h/2)
                x2 = float(x + w/2)
                y2 = float(y + h/2)
                
                # Add detection to results
                detection = {
                    "class_id": int(class_id),
                    "label": labels[class_id] if class_id < len(labels) else f"Class {class_id}",
                    "confidence": confidence,
                    "bbox": [x1, y1, x2, y2]
                }
                results.append(detection)
    
    # Non-Maximum Suppression would be applied here
    # (Implementation details omitted for brevity)
    
    return results
```

## 5. Complete Example

Here's a simple example showing how to use these components together:

```python
# Example usage
from preprocessing import preprocess_image_yolo
from inference import create_inference_session, run_inference
from postprocessing import postprocess_yolo_output

# Configuration
MODEL_PATH = "models/yolov8s_quantized.onnx"
IMAGE_PATH = "test_images/sample.jpg"
LABELS_PATH = "labels/coco.names"

# Setup inference session
session = create_inference_session(MODEL_PATH)

# Preprocess input image
input_data = preprocess_image_yolo(IMAGE_PATH)

# Run inference (core operation)
outputs = run_inference(session, input_data)

# Postprocess results
detections = postprocess_yolo_output(
    outputs, 
    conf_threshold=0.25,
    iou_threshold=0.45,
    labels_path=LABELS_PATH
)

# Display results
print(f"Found {len(detections)} objects:")
for det in detections:
    print(f"{det['label']} ({det['confidence']:.2f}): {det['bbox']}")
```

## 6. Important Notes

### Performance Optimization

- **Pillow-SIMD**: The documentation uses Pillow-SIMD instead of regular Pillow for faster image processing. This can significantly improve preprocessing speed.
- **Batch Processing**: If processing multiple images, consider implementing batch processing to maximize throughput.

### Input and Output Formats

For YOLOv8 models:
- **Input**: Batch of images in NCHW format (N=batch size, C=channels, H=height, W=width)
- **Output**: Detection results in format [batch, num_detections, 4+1+num_classes]

### Execution Provider

This implementation uses exclusively the BarqExecutionProvider*. Ensure that it's available in your ONNX Runtime build before running the inference code.

### Troubleshooting

1. **Model loading errors**:
   - Check file path
   - Verify model format compatibility

2. **Shape mismatches**:
   - Verify input shape with `print(session.get_inputs()[0].shape)`
   - Adjust preprocessing accordingly

3. **Low performance**:
   - Try different execution providers
   - Optimize with quantized models

## 7. Model Optimization with Microsoft Olive

For model fine-tuning and optimization, you can use Microsoft's Olive tool:

```bash
# Install Olive
pip install olive-ai

# Basic usage example
olive optimize --model model.onnx --config olive_config.json --output optimized_model
```

Olive provides several optimization techniques, including:
- Quantization (INT8, FP16)
- Pruning
- Knowledge distillation
- Graph optimizations

Refer to the [Olive GitHub repository](https://github.com/microsoft/Olive) for detailed documentation and examples.

## 8. Additional ONNX Runtime Resources

- [Performance Tuning Guide](https://onnxruntime.ai/docs/performance/tune-performance.html)
- [Execution Providers](https://onnxruntime.ai/docs/execution-providers/)
- [API Reference](https://onnxruntime.ai/docs/api/)
