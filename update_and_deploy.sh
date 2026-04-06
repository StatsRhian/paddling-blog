#!/bin/bash

# Exit on any error
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Update Paddle Blog ===${NC}"
echo

# Step 1: Run R script
echo -e "${YELLOW}Step 1: Running R script...${NC}"
if [ -f "R/set_up.R" ]; then
    Rscript R/set_up.R
    echo -e "${GREEN}✓ R script completed${NC}"
else
    echo -e "${RED}Error: R/set_up.R not found${NC}"
    exit 1
fi
echo

# Step 2: Render Quarto website
echo -e "${YELLOW}Step 2: Rendering Quarto website...${NC}"
quarto render
echo -e "${GREEN}✓ Quarto website rendered${NC}"
echo

# Step 3: Show git status
echo -e "${YELLOW}Step 3: Checking for changes...${NC}"
git status
echo

# Step 4: Ask for user confirmation
echo -e "${YELLOW}Do you want to commit and push these changes? (y/n)${NC}"
read -r response

if [[ "$response" =~ ^[Yy]$ ]]; then
    # Get today's date
    TODAY=$(date +%Y-%m-%d)

    # Step 5: Git operations
    echo -e "${YELLOW}Step 5: Committing and pushing changes...${NC}"
    git add -A
    git commit -m ":card_file_box: Update $TODAY"
    git push

    echo -e "${GREEN}✓ Changes committed and pushed successfully!${NC}"
else
    echo -e "${RED}Operation cancelled by user${NC}"
    exit 0
fi

echo
echo -e "${GREEN}=== All done! ===${NC}"
