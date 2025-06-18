!/bin/bash

# --- Налаштування репозиторію (можна змінити ці значення за потреби) ---
GITHUB_USERNAME="Alexsik76" # Ваше ім'я користувача на GitHub
GITHUB_REPO="configs"     # Назва вашого приватного репозиторію з конфігураціями

# --- Перевірка наявності jq ---
if ! command -v jq &> /dev/null
then
    echo "Помилка: Утиліта 'jq' не знайдена." >&2
    echo "Будь ласка, встановіть її (наприклад, 'sudo apt install jq' або 'sudo dnf install jq')." >&2
    exit 1
fi

# --- Функція для обробки помилок ---
error_exit() {
    echo "Помилка: $1" >&2
    exit 1
}

echo "--- Завантаження конфігураційного файлу з GitHub ---"
echo "Репозиторій: ${GITHUB_USERNAME}/${GITHUB_REPO}"

# --- Крок 1: Отримати Personal Access Token (PAT) безпечно ---
echo "Будь ласка, введіть ваш GitHub Personal Access Token (PAT):"
read -s GITHUB_TOKEN # -s робить введення невидимим і не зберігає його в історії команд
echo # Додаємо порожній рядок для кращого вигляду в консолі

[[ -z "$GITHUB_TOKEN" ]] && error_exit "PAT не може бути порожнім."

# --- Допоміжна функція для виконання запитів до GitHub API ---
# Аргументи: $1 = Шлях API-кінцевої точки (наприклад, 'contents/')
# Повертає: JSON-відповідь або порожній рядок у разі помилки
github_api_request() {
    local api_path="$1"
    local full_url="https://api.github.com/repos/${GITHUB_USERNAME}/${GITHUB_REPO}/${api_path}"

    # Використовуємо -sL для тихого режиму та слідування редіректам
    # --fail-with-body для виведення тіла відповіді при помилці (наприклад, 404/403)
    # 2>/dev/null приховує прогрес curl та помилки від самого curl (якщо їх не хочемо бачити)
    curl -sL --fail-with-body \
         -H "Authorization: token $GITHUB_TOKEN" \
         -H "Accept: application/vnd.github.v3+json" \
         "$full_url" 2>/dev/null
}

# --- Допоміжна функція для вилучення імен з JSON-масиву ---
# Аргументи: $1 = JSON-рядок
# Повертає: Список імен, розділених новими рядками
parse_json_names() {
    echo "$1" | jq -r '.[].name'
}

# --- Крок 2: Прочитати структуру папок та дозволити вибір ---
echo ""
echo "Завантаження списку папок у репозиторії..."
API_RESPONSE=$(github_api_request "contents/")

# Перевірка на помилки запиту API
if [ $? -ne 0 ]; then
    error_exit "Не вдалося отримати список папок. Перевірте PAT, ім'я користувача або назву репозиторію. Можливо, токен не має дозволу 'repo'."
fi
# Перевірка на порожню відповідь
[[ -z "$API_RESPONSE" ]] && error_exit "Отримано порожню відповідь API. Можливо, репозиторій порожній або шлях невірний."

declare -a DIRECTORIES_ARRAY # Масив для зберігання імен папок
declare -A DIR_MAP         # Асоціативний масив для відображення номерів на імена папок

i=1
echo "Доступні папки:"
# Використовуємо jq для фільтрації лише директорій та отримання їх імен
while IFS= read -r item_name; do
    item_type=$(echo "$API_RESPONSE" | jq -r ".[] | select(.name == \"$item_name\") | .type")
    if [[ "$item_type" == "dir" ]]; then
        DIRECTORIES_ARRAY+=("$item_name")
        DIR_MAP[$i]="$item_name"
        echo "  $i) $item_name"
        ((i++))
    fi
done < <(parse_json_names "$API_RESPONSE")

if [ ${#DIRECTORIES_ARRAY[@]} -eq 0 ]; then
    error_exit "Не знайдено жодної папки в корені репозиторію. Перевірте структуру вашого репозиторію 'configs'."
fi

SELECTED_DIR_INDEX=""
while true; do
    read -p "Введіть номер папки для вибору: " SELECTED_DIR_INDEX
    if [[ "$SELECTED_DIR_INDEX" =~ ^[0-9]+$ ]] && \
       (( SELECTED_DIR_INDEX >= 1 && SELECTED_DIR_INDEX <= ${#DIRECTORIES_ARRAY[@]} )); then
        break
    else
        echo "Невірний вибір. Будь ласка, введіть дійсний номер."
    fi
done
SELECTED_DIRECTORY="${DIR_MAP[$SELECTED_DIR_INDEX]}"
echo "Вибрано папку: ${SELECTED_DIRECTORY}"

# --- Крок 3: Прочитати список файлів в обраній папці та дозволити вибір ---
echo ""
echo "Завантаження списку файлів в папці '${SELECTED_DIRECTORY}'..."
API_RESPONSE=$(github_api_request "contents/${SELECTED_DIRECTORY}")

if [ $? -ne 0 ]; then
    error_exit "Не вдалося отримати список файлів у папці '${SELECTED_DIRECTORY}'. Перевірте доступ або шлях."
fi
[[ -z "$API_RESPONSE" ]] && error_exit "Отримано порожню відповідь API для папки '${SELECTED_DIRECTORY}'. Можливо, вона порожня."

declare -a FILES_ARRAY # Масив для зберігання імен файлів
declare -A FILE_MAP    # Асоціативний масив для відображення номерів на імена файлів

j=1
echo "Доступні файли в '${SELECTED_DIRECTORY}':"
# Використовуємо jq для фільтрації лише файлів та отримання їх імен
while IFS= read -r item_name; do
    item_type=$(echo "$API_RESPONSE" | jq -r ".[] | select(.name == \"$item_name\") | .type")
    if [[ "$item_type" == "file" ]]; then
        FILES_ARRAY+=("$item_name")
        FILE_MAP[$j]="$item_name"
        echo "  $j) $item_name"
        ((j++))
    fi
done < <(parse_json_names "$API_RESPONSE")

if [ ${#FILES_ARRAY[@]} -eq 0 ]; then
    error_exit "Не знайдено жодного файлу в папці '${SELECTED_DIRECTORY}'. Перевірте структуру."
fi

SELECTED_FILE_INDEX=""
while true; do
    read -p "Введіть номер файлу для вибору: " SELECTED_FILE_INDEX
    if [[ "$SELECTED_FILE_INDEX" =~ ^[0-9]+$ ]] && \
       (( SELECTED_FILE_INDEX >= 1 && SELECTED_FILE_INDEX <= ${#FILES_ARRAY[@]} )); then
        break
    else
        echo "Невірний вибір. Будь ласка, введіть дійсний номер."
    fi
done
SELECTED_FILE="${FILE_MAP[$SELECTED_FILE_INDEX]}"
echo "Вибрано файл: ${SELECTED_FILE}"

# --- Крок 4: Завантаження обраного файлу ---
echo ""
# Пропонуємо шлях за замовчуванням, але дозволяємо користувачеві його змінити
DEFAULT_LOCAL_PATH="/tmp/${SELECTED_FILE}"
read -p "Введіть повний шлях, куди зберегти файл на сервері (за замовчуванням: '${DEFAULT_LOCAL_PATH}'): " LOCAL_FILE_PATH

# Якщо користувач ввів порожній шлях, використовуємо шлях за замовчуванням
if [[ -z "$LOCAL_FILE_PATH" ]]; then
    LOCAL_FILE_PATH="${DEFAULT_LOCAL_PATH}"
fi

# Формуємо URL для завантаження сирого вмісту файлу
FILE_DOWNLOAD_URL="https://api.github.com/repos/${GITHUB_USERNAME}/${GITHUB_REPO}/contents/${SELECTED_DIRECTORY}/${SELECTED_FILE}"

echo "Спроба завантажити файл з: $FILE_DOWNLOAD_URL"
echo "Зберегти до: $LOCAL_FILE_PATH"

# Виконуємо завантаження
# Використовуємо --fail-with-body, щоб curl виводив тіло помилки з сервера (наприклад, 404/403)
# Використовуємо -sL для тихого режиму та слідування редіректам
curl_output=$(curl -sL --fail-with-body \
                   -H "Authorization: token $GITHUB_TOKEN" \
                   -H "Accept: application/vnd.github.v3.raw" \
                   -o "$LOCAL_FILE_PATH" \
                   "$FILE_DOWNLOAD_URL" 2>&1) # Направляємо stderr в stdout для перехоплення помилок

# Перевірка статусу виконання curl
if [ $? -eq 0 ]; then
    echo "Файл '$SELECTED_FILE' успішно завантажено до '$LOCAL_FILE_PATH'."
else
    echo "Помилка завантаження файлу:" >&2
    echo "$curl_output" >&2 # Виводимо повідомлення про помилку від curl
    echo "Перевірте правильність введених даних, PAT або дозволи на доступ до файлу/репозиторію." >&2
    exit 1
fi

# Очищення змінної оточення PAT (хоча вона була локальною для цього скрипта, це хороша практика)
unset GITHUB_TOKEN

echo "--- Операція завершена ---"
exit 0
