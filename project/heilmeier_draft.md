**Question 1: What are you trying to do?**

I am designing a hardware accelerator for Convolutional Neural Networks (CNNs) tailored for edge devices used in industrial settings. The goal is to enable fast, efficient AI processing on small devices such as cameras or sensors, allowing tasks like defect detection, image recognition, and equipment monitoring to be performed locally without relying on large servers or cloud computing.

**Question 2: How is it done today, and what are the limits of current practice?**

Currently, CNNs are primarily executed on high performance GPUs or cloud servers. While this provides strong computational power, it is unsuitable for edge deployment due to high energy consumption, latency, and hardware size. Existing edge AI solutions are either limited in performance or require simplifications to the models, reducing accuracy and efficiency in real world industrial environments.

**Question 3: What is new in your approach and why do you think it will be successful?**

My approach introduces a custom, parallelized hardware accelerator using fixed-point arithmetic to optimize both speed and energy efficiency. Implemented in SystemVerilog and validated through Icarus Verilog and QuestaSim simulations, this design provides a practical method for high performance CNN execution on resource constrained edge devices. By focusing on both architectural efficiency and correctness verification, I believe this solution can bridge the gap between high performance AI and practical industrial deployment.
