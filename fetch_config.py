import os
import sys
import json
import urllib.request
import urllib.error
import getpass # Для безпечного введення токена

# Цей скрипт призначений для безпечного завантаження конфігураційних файлів
# з конкретного приватного GitHub репозиторію.
# Він інтерактивно дозволяє вибрати папку та файл для завантаження.

# --- Налаштування репозиторію (можна змінити ці значення за потреби) ---
GITHUB_USERNAME = "Alexsik76" # Ваше ім'я користувача на GitHub
GITHUB_REPO = "configs"     # Назва вашого приватного репозиторію з конфігураціями

# --- Функція для обробки помилок ---
def error_exit(message):
    print(f"Помилка: {message}", file=sys.stderr)
    sys.exit(1)

print("--- Завантаження конфігураційного файлу з GitHub ---")
print(f"Репозиторій: {GITHUB_USERNAME}/{GITHUB_REPO}")

# --- Крок 1: Отримати Personal Access Token (PAT) безпечно ---
print("Будь ласка, введіть ваш GitHub Personal Access Token (PAT):")
try:
    # getpass.getpass() приховує введення і не зберігає його в історії
    GITHUB_TOKEN = getpass.getpass("") 
except Exception as e:
    error_exit(f"Не вдалося прочитати PAT: {e}")

if not GITHUB_TOKEN:
    error_exit("PAT не може бути порожнім.")

# --- Допоміжна функція для виконання запитів до GitHub API ---
# Аргументи: api_path = Шлях API-кінцевої точки (наприклад, 'contents/')
#            accept_header = Заголовок Accept для запиту
# Повертає: JSON-об'єкт або вміст файлу у байтах
def github_api_request(api_path, accept_header="application/vnd.github.v3+json"):
    full_url = f"https://api.github.com/repos/{GITHUB_USERNAME}/{GITHUB_REPO}/{api_path}"
    
    headers = {
        "Authorization": f"token {GITHUB_TOKEN}",
        "Accept": accept_header
    }
    
    req = urllib.request.Request(full_url, headers=headers)
    
    try:
        with urllib.request.urlopen(req) as response:
            if accept_header == "application/vnd.github.v3.raw":
                return response.read() # Повертаємо сирі байти файлу
            else:
                return json.loads(response.read().decode('utf-8')) # Повертаємо JSON
    except urllib.error.HTTPError as e:
        error_message = f"HTTP Помилка при запиті до {full_url}: {e.code} {e.reason}"
        try:
            # Спроба прочитати тіло відповіді для детальнішої помилки
            error_body = e.read().decode('utf-8')
            error_message += f"\nТіло відповіді: {error_body}"
        except:
            pass # Неможливо прочитати тіло помилки
        error_exit(error_message)
    except urllib.error.URLError as e:
        error_exit(f"Помилка URL при запиті до {full_url}: {e.reason}")
    except json.JSONDecodeError:
        error_exit(f"Не вдалося розібрати JSON-відповідь для {full_url}. Можливо, отримано не JSON.")
    except Exception as e:
        error_exit(f"Неочікувана помилка при запиті до {full_url}: {e}")

# --- Крок 2: Прочитати структуру папок та дозволити вибір ---
print("\nЗавантаження списку папок у репозиторії...")
api_response_json = github_api_request("contents/")

if not api_response_json:
    error_exit("Отримано порожню відповідь API. Можливо, репозиторій порожній або шлях невірний.")

directories_list = []
dir_map = {} # Для відображення номерів на імена папок

print("Доступні папки:")
for item in api_response_json:
    if item.get('type') == 'dir':
        directories_list.append(item['name'])

if not directories_list:
    error_exit(f"Не знайдено жодної папки в корені репозиторію '{GITHUB_REPO}'. Перевірте структуру.")

for i, dir_name in enumerate(directories_list):
    dir_map[str(i + 1)] = dir_name
    print(f"  {i + 1}) {dir_name}")

selected_dir_index = ""
while True:
    selected_dir_index = input("Введіть номер папки для вибору: ")
    if selected_dir_index.isdigit() and selected_dir_index in dir_map:
        break
    else:
        print("Невірний вибір. Будь ласка, введіть дійсний номер.")

SELECTED_DIRECTORY = dir_map[selected_dir_index]
print(f"Вибрано папку: {SELECTED_DIRECTORY}")

# --- Крок 3: Прочитати список файлів в обраній папці та дозволити вибір ---
print(f"\nЗавантаження списку файлів в папці '{SELECTED_DIRECTORY}'...")
api_response_json = github_api_request(f"contents/{SELECTED_DIRECTORY}")

if not api_response_json:
    error_exit(f"Отримано порожню відповідь API для папки '{SELECTED_DIRECTORY}'. Можливо, вона порожня.")

files_list = []
file_map = {} # Для відображення номерів на імена файлів

print(f"Доступні файли в '{SELECTED_DIRECTORY}':")
for item in api_response_json:
    if item.get('type') == 'file':
        files_list.append(item['name'])

if not files_list:
    error_exit(f"Не знайдено жодного файлу в папці '{SELECTED_DIRECTORY}'. Перевірте структуру.")

for j, file_name in enumerate(files_list):
    file_map[str(j + 1)] = file_name
    print(f"  {j + 1}) {file_name}")

selected_file_index = ""
while True:
    selected_file_index = input("Введіть номер файлу для вибору: ")
    if selected_file_index.isdigit() and selected_file_index in file_map:
        break
    else:
        print("Невірний вибір. Будь ласка, введіть дійсний номер.")

SELECTED_FILE = file_map[selected_file_index]
print(f"Вибрано файл: {SELECTED_FILE}")

# --- Крок 4: Завантаження обраного файлу ---
print("")
# Пропонуємо шлях за замовчуванням, але дозволяємо користувачеві його змінити
default_local_path = os.path.join("/tmp", SELECTED_FILE)
local_file_path = input(f"Введіть повний шлях, куди зберегти файл на сервері (за замовчуванням: '{default_local_path}'): ")

# Якщо користувач ввів порожній шлях, використовуємо шлях за замовчуванням
if not local_file_path:
    local_file_path = default_local_path

# Формуємо URL для завантаження сирого вмісту файлу
file_api_path = f"contents/{SELECTED_DIRECTORY}/{SELECTED_FILE}"

print(f"Спроба завантажити файл з: https://api.github.com/repos/{GITHUB_USERNAME}/{GITHUB_REPO}/{file_api_path}")
print(f"Зберегти до: {local_file_path}")

try:
    file_content = github_api_request(file_api_path, accept_header="application/vnd.github.v3.raw")
    
    with open(local_file_path, 'wb') as f:
        f.write(file_content)
    
    print(f"Файл '{SELECTED_FILE}' успішно завантажено до '{local_file_path}'.")
except Exception as e:
    error_exit(f"Помилка завантаження файлу: {e}\nПеревірте правильність введених даних, PAT або дозволи на доступ до файлу/репозиторію.")

print("--- Операція завершена ---")
sys.exit(0)
