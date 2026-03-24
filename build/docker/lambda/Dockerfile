FROM public.ecr.aws/lambda/python:3.14-arm64
# Apply OS updates and update Pip
RUN dnf upgrade -y \
    && dnf clean all \
    && rm -rf /var/cache/dnf \
    && python -m pip install --upgrade pip
# Copy Python requirements
COPY assets/requirements.txt /
# Install Python requirements
RUN pip install -r /requirements.txt --upgrade
# Copy function code
ADD assets/app.tar.gz "/var/task"
# Set the CMD to your handler
CMD [ "CMD_TO_REPLACE" ]
