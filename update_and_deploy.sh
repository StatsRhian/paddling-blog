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
# Step 2: Check for git changes
echo -e "${YELLOW}Step 2: Checking for changes...${NC}"
git status
echo
if git diff --quiet && git diff --staged --quiet; then
    echo -e "${YELLOW}No git changes detected. Skipping commit, push, and publish.${NC}"
    echo -e "${GREEN}=== All done! ===${NC}"
    exit 0
fi
# Step 3: Ask for user confirmation
echo -e "${YELLOW}Do you want to commit, push, and publish these changes? (y/n)${NC}"
read -r response
if [[ "$response" =~ ^[Yy]$ ]]; then
    # Get today's date
    TODAY=$(date +%Y-%m-%d)
    # Step 4: Git operations
    echo -e "${YELLOW}Step 4: Committing and pushing changes...${NC}"
    git add -A
    git commit -m ":card_file_box: Update $TODAY"
    git push
    echo -e "${GREEN}✓ Changes committed and pushed successfully!${NC}"
    echo
    # Step 5: Publish Quarto website (only if there were changes)
    echo -e "${YELLOW}Step 5: Publishing Quarto website to Netlify...${NC}"
    quarto publish netlify
    echo -e "${GREEN}✓ Quarto website published${NC}"
else
    echo -e "${RED}Operation cancelled by user${NC}"
    exit 0
fi
echo
echo -e "${GREEN}=== All done! ===${NC}"
