# Use the official Node 8 image.
# https://hub.docker.com/_/node 
# Try the bookworm supported debian version 
FROM node:bookworm 

# Create and change to the app directory.
WORKDIR /usr/src/app

# Copy application dependency manifests to the container image.
# A wildcard is used to ensure both package.json AND package-lock.json are copied.
# Copying this separately prevents re-running npm install on every code change.
COPY package*.json ./
 
COPY html html
COPY app.js app.js 

# Install production dependencies.
RUN npm install --only=production
 
# Configure and document the service HTTP port.
ENV PORT 8080
EXPOSE $PORT

# Run the web service on container startup.
CMD [ "node", "app.js" ]

