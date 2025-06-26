#!/bin/bash

# Function to display usage
usage() {
    echo "Usage: $0 <language> <file>"
    echo "       Supported languages: python, javascript, bash"
    echo ""
    echo "Options for pretty-printing (each language may have specific sub-options or styles):"
    echo "  python: Uses 'black'"
    echo "  javascript: Uses 'prettier'"
    echo "  bash: Uses 'shfmt' or 'bashbeautify'"
    exit 1
}

# Check if at least two arguments are provided
if [[ "$#" -lt 2 ]]; then
    usage
fi

LANGUAGE="$1"
FILE="$2"

# Check if the file exists
if [[ ! -f "$FILE" ]]; then
    echo "Error: File '$FILE' not found."
    exit 1
fi

case "$LANGUAGE" in
    "python")
        echo "Pretty-printing Python file: $FILE"
        if command -v black &> /dev/null; then
            # You could add options here for black, e.g., black --line-length 79 "$FILE"
            black "$FILE"
            if [[ $? -eq 0 ]]; then
                echo "Python file pretty-printed successfully."
            else
                echo "Error: 'black' failed to pretty-print the Python file."
            fi
        else
            echo "Error: 'black' (Python formatter) not found. Please install it: pip install black"
            echo "Cannot pretty-print Python."
        fi
        ;;
    "javascript")
        echo "Pretty-printing JavaScript/Node.js file: $FILE"
        if command -v prettier &> /dev/null; then
            # You could add options here for prettier, e.g., prettier --write --print-width 80 "$FILE"
            prettier --write "$FILE"
            if [[ $? -eq 0 ]]; then
                echo "JavaScript file pretty-printed successfully."
            else
                echo "Error: 'prettier' failed to pretty-print the JavaScript file."
            fi
        else
            echo "Error: 'prettier' (JavaScript formatter) not found. Please install it: npm install -g prettier"
            echo "Cannot pretty-print JavaScript."
        fi
        ;;
    "bash")
        echo "Pretty-printing Bash file: $FILE"
        if command -v shfmt &> /dev/null; then
            # shfmt has various options, e.g., shfmt -i 4 -w "$FILE" (indent 4 spaces, write in place)
            shfmt -w "$FILE"
            if [[ $? -eq 0 ]]; then
                echo "Bash file pretty-printed successfully."
            else
                echo "Error: 'shfmt' failed to pretty-print the Bash file."
            fi
        elif command -v bashbeautify &> /dev/null; then
            # bashbeautify is another option, usually output to stdout, so you'd redirect
            bashbeautify "$FILE" > "${FILE}.pretty"
            if [[ $? -eq 0 ]]; then
                echo "Bash file pretty-printed to ${FILE}.pretty. Original file untouched."
            else
                echo "Error: 'bashbeautify' failed to pretty-print the Bash file."
            fi
        else
            echo "Error: 'shfmt' or 'bashbeautify' (Bash formatters) not found."
            echo "Please install one of them. For shfmt: go install mvdan.cc/sh/v3/cmd/shfmt@latest"
            echo "Cannot pretty-print Bash."
        fi
        ;;
    *)
        echo "Error: Unsupported language '$LANGUAGE'."
        usage
        ;;
esac

echo ""
echo "--- Suggestions for Advanced System Controls (related to code management): ---"
echo "1. **Version Control Integration:** Use Git (or similar) to track changes. Before pretty-printing, commit your current work. This allows you to easily revert if the formatting isn't what you expected."
echo "   Example: 'git add . && git commit -m \"Before pretty-printing\"'"
echo "2. **Pre-commit Hooks:** Automate code formatting using pre-commit hooks in Git. This ensures that all code committed to your repository adheres to a consistent style."
echo "   Tool: 'pre-commit' (pip install pre-commit)"
echo "   Example: Add 'black' or 'prettier' to your .pre-commit-config.yaml"
echo "3. **CI/CD Pipeline Integration:** Integrate code formatting checks and auto-formatting into your Continuous Integration/Continuous Deployment (CI/CD) pipeline."
echo "   This ensures that only properly formatted code is deployed."
echo "   Tools: Jenkins, GitLab CI/CD, GitHub Actions, Travis CI, etc."
echo "4. **IDE/Editor Integration:** Configure your Integrated Development Environment (IDE) or text editor to automatically format code on save or on paste."
echo "   Most modern IDEs (VS Code, IntelliJ, PyCharm) have built-in support or extensions for popular formatters."
echo "5. **Containerization for Consistent Environments:** Use Docker or other containerization technologies to ensure that your formatting tools run in a consistent environment, avoiding 'works on my machine' issues."
echo "   Example: A Dockerfile that includes Python and 'black'."
echo "6. **Language Server Protocol (LSP):** Leverage LSP-compatible tools in your editor for real-time syntax checking, auto-completion, and formatting suggestions."
echo "   While not directly formatting, it helps maintain code quality."
