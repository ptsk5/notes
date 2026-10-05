
# Add this to your ~/.bashrc or ~/.bash_profile
oc-gpu() {
  if [ -z "$1" ]; then
    echo "Usage: oc-gpu <node-name>"
    return 1
  fi

  oc describe node "$1" | awk '
    BEGIN { section = "" }
    /^Capacity:/     { section = "Capacity"; next }
    /^Allocatable:/  { section = "Allocatable"; next }
    /^Allocated resources:/ { section = "Allocated"; next }
    /^[^[:space:]]/  { section = ""; next }

    section != "" && $1 ~ /^nvidia\.com\// {
      printf "[%s] %s %s\n", section, $1, $2
    }
  '
}