from torchvision.models import resnet18
from torchinfo import summary

model = resnet18()
model.eval()

info = summary(
    model,
    input_size=(1, 3, 224, 224),
    col_names=("input_size", "output_size", "num_params", "mult_adds"),
    verbose=1
)
