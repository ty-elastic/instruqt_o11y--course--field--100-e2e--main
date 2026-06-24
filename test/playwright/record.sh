if [ -f ".env" ]; then
    set -o allexport # Automatically export all variables defined after this point
    source .env
    set +o allexport # Stop automatic exporting
fi

npx playwright codegen $INSTRUQT_INVITE
