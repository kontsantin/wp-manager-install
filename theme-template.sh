#!/bin/bash
# Скрипт для создания структуры темы WordPress
# Функции для использования из основного скрипта wpmanager

create_theme_files() {
    local THEME_DIR="$1"
    local THEME_NAME="$2"
    local WP_PATH="$3"

    if [[ -z "$THEME_DIR" || -z "$THEME_NAME" ]]; then
        echo "Theme dir or name is empty" >&2
        return 1
    fi

    mkdir -p "$THEME_DIR"
    mkdir -p "$THEME_DIR/inc/composer"
    mkdir -p "$THEME_DIR/templates"
    mkdir -p "$THEME_DIR/templates/parts"

    # composer.json в папке inc/composer для carbon fields (пользователь может запустить composer install)
    cat > "$THEME_DIR/inc/composer/composer.json" <<JSON
{
  "name": "${THEME_NAME}/theme",
  "description": "Theme for ${THEME_NAME}",
  "require": {
    "htmlburger/carbon-fields": "^3.3"
  }
}
JSON

        # Если есть composer, автоматически устанавливаем зависимости (carbon fields)
        if command -v composer >/dev/null 2>&1; then
                echo "Running composer install for Carbon Fields..."
                (cd "$THEME_DIR/inc/composer" && composer install --no-interaction --prefer-dist) >/dev/null 2>&1 || {
                        echo "Warning: composer install failed in $THEME_DIR/inc/composer" >&2
                }
        else
                echo "Note: composer not found. To install Carbon Fields, run:"
                echo "  cd $THEME_DIR/inc/composer && composer install"
        fi

    # assets.php - массив скриптов/стилей (ключ => [path, deps, in_footer])
    cat > "$THEME_DIR/inc/assets.php" <<'PHP'
<?php
// Массив ассетов: порядок в массиве = приоритет (первый - выше)
$theme_assets = array(
    // handle => array('path', array('deps'), in_footer)
    'theme-style' => array('style.css', array(), false),
    'theme-main'  => array('js/main.js', array('jquery'), true),
);

return $theme_assets;
PHP

    # enqueue.php - подключение ассетов, подключает assets.php
    cat > "$THEME_DIR/inc/enqueue.php" <<'PHP'
<?php
$assets = require __DIR__ . '/assets.php';
foreach ($assets as $handle => $info) {
    $path = get_template_directory_uri() . '/' . $info[0];
    if (strpos($info[0], '.css') !== false) {
        wp_enqueue_style($handle, $path, isset($info[1]) ? $info[1] : array(), filemtime(get_template_directory() . '/' . $info[0]));
    } else {
        wp_enqueue_script($handle, $path, isset($info[1]) ? $info[1] : array(), filemtime(get_template_directory() . '/' . $info[0]), isset($info[2]) ? $info[2] : true);
    }
}
PHP

    # menu.php - регистрация меню
    cat > "$THEME_DIR/inc/menu.php" <<'PHP'
<?php
function theme_register_menus() {
    register_nav_menus(array(
        'primary' => __('Primary Menu', 'theme'),
    ));
}
add_action('after_setup_theme', 'theme_register_menus');
PHP

    # cpts.php - пример регистрации custom post type
    cat > "$THEME_DIR/inc/cpts.php" <<'PHP'
<?php
function theme_register_cpts() {
    register_post_type('portfolio', array(
        'labels' => array('name' => 'Portfolio'),
        'public' => true,
        'has_archive' => true,
        'supports' => array('title','editor','thumbnail')
    ));
}
add_action('init', 'theme_register_cpts');
PHP

    # functions.php - подключаем enqueue и assets
    cat > "$THEME_DIR/functions.php" <<PHP
<?php
// Подключаем файлы из inc
require_once __DIR__ . '/inc/enqueue.php';
require_once __DIR__ . '/inc/assets.php';
require_once __DIR__ . '/inc/menu.php';
require_once __DIR__ . '/inc/cpts.php';

// Точка входа для Carbon Fields, если установлен через composer
if ( file_exists( __DIR__ . '/inc/composer/vendor/autoload.php' ) ) {
    require_once __DIR__ . '/inc/composer/vendor/autoload.php';
    \Carbon_Fields\Carbon_Fields::boot();
}
PHP

    # header.php и footer.php простые шаблоны
    cat > "$THEME_DIR/header.php" <<'PHP'
<!DOCTYPE html>
<html <?php language_attributes(); ?>>
<head>
  <meta charset="<?php bloginfo('charset'); ?>">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <?php wp_head(); ?>
</head>
<body <?php body_class(); ?>>
<header>
  <nav><?php wp_nav_menu(array('theme_location'=>'primary')); ?></nav>
</header>
PHP

    cat > "$THEME_DIR/footer.php" <<'PHP'
<footer>
  <p>&copy; <?php echo date('Y'); ?></p>
</footer>
<?php wp_footer(); ?>
</body>
</html>
PHP

    # Создаём минимальные файлы шаблонов
    cat > "$THEME_DIR/index.php" <<'PHP'
<?php get_header(); ?>
<main>
  <?php if (have_posts()) : while (have_posts()) : the_post(); ?>
    <article id="post-<?php the_ID(); ?>">
      <h2><?php the_title(); ?></h2>
      <div><?php the_content(); ?></div>
    </article>
  <?php endwhile; endif; ?>
</main>
<?php get_footer(); ?>
PHP

    # Создаём пустые ассеты (JS/CSS), чтобы пути существовали
    mkdir -p "$THEME_DIR/js"
    touch "$THEME_DIR/js/main.js"
    touch "$THEME_DIR/style.css"

    echo "Theme $THEME_NAME created at $THEME_DIR"
}

export -f create_theme_files
