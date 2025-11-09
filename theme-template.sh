#!/bin/bash
# theme-builder.sh
# Функция для создания структуры темы WordPress

create_theme_files() {
    local THEME_DIR="$1"
    local THEME_NAME="$2"
    local WP_PATH="$3"

    if [[ -z "$THEME_DIR" || -z "$THEME_NAME" ]]; then
        echo "Theme dir or name is empty" >&2
        return 1
    fi

    # Безопасное имя для text-domain / PHP-функций:
    # - привести к lowercase
    # - заменить все не-латинские/нецифровые символы на '_' (включая тире -> '_')
    # - убрать повторяющиеся '_' и обрезать ведущие/хвостовые
    SAFE_NAME=$(echo "$THEME_NAME" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/_/g' | sed 's/_\+/_/g' | sed 's/^_//' | sed 's/_$//')
    # Если имя начинается с цифры, добавить префикс чтобы имя функции было валидным
    if [[ $SAFE_NAME =~ ^[0-9] ]]; then
        SAFE_NAME="t_$SAFE_NAME"
    fi

    mkdir -p "$THEME_DIR"
    mkdir -p "$THEME_DIR/inc/composer"
    mkdir -p "$THEME_DIR/templates"
    mkdir -p "$THEME_DIR/templates-parts"
    mkdir -p "$THEME_DIR/assets/css"
    mkdir -p "$THEME_DIR/assets/js"
    mkdir -p "$THEME_DIR/assets/images"

    # composer.json для Carbon Fields
    cat > "$THEME_DIR/inc/composer/composer.json" <<JSON
{
  "name": "${THEME_NAME}/theme",
  "description": "Theme for ${THEME_NAME}",
  "require": {
    "htmlburger/carbon-fields": "^3.3"
  }
}
JSON

    # Composer install, если есть
    if command -v composer >/dev/null 2>&1; then
        echo "Running composer install for Carbon Fields..."
        (cd "$THEME_DIR/inc/composer" && composer install --no-interaction --prefer-dist) >/dev/null 2>&1 || {
            echo "Warning: composer install failed" >&2
        }
    else
        echo "Composer not found. To install Carbon Fields, run:"
        echo "cd $THEME_DIR/inc/composer && composer install"
    fi

    # assets.php
    cat > "$THEME_DIR/inc/assets.php" <<'PHP'
<?php
$theme_assets = array(
    'theme-style' => array('assets/css/main.css', array(), false),
    'theme-main'  => array('assets/js/main.js', array('jquery'), true),
);
return $theme_assets;
PHP

    # enqueue.php — регистрируем ассеты в правильном хуке
    cat > "$THEME_DIR/inc/enqueue.php" <<PHP
<?php
function ${SAFE_NAME}_enqueue_assets() {
    \$assets = require __DIR__ . '/assets.php';
    foreach (\$assets as \$handle => \$info) {
        \$path = get_template_directory_uri() . '/' . \$info[0];
        if (strpos(\$info[0], '.css') !== false) {
            wp_enqueue_style(\$handle, \$path, isset(\$info[1]) ? \$info[1] : array(), file_exists(get_template_directory() . '/' . \$info[0]) ? filemtime(get_template_directory() . '/' . \$info[0]) : null);
        } else {
            wp_enqueue_script(\$handle, \$path, isset(\$info[1]) ? \$info[1] : array(), file_exists(get_template_directory() . '/' . \$info[0]) ? filemtime(get_template_directory() . '/' . \$info[0]) : null, isset(\$info[2]) ? \$info[2] : true);
        }
    }
}
add_action('wp_enqueue_scripts', '${SAFE_NAME}_enqueue_assets');
PHP

    # menu.php
    cat > "$THEME_DIR/inc/menu.php" <<PHP
<?php
function ${SAFE_NAME}_register_menus() {
    register_nav_menus(array(
        'primary' => __('Primary Menu', '${SAFE_NAME}'),
    ));
}
add_action('after_setup_theme', '${SAFE_NAME}_register_menus');
PHP

    # cpts.php
    cat > "$THEME_DIR/inc/cpts.php" <<PHP
<?php
function ${SAFE_NAME}_register_cpts() {
    register_post_type('portfolio', array(
        'labels' => array('name' => 'Portfolio'),
        'public' => true,
        'has_archive' => true,
        'supports' => array('title','editor','thumbnail')
    ));
}
add_action('init', '${SAFE_NAME}_register_cpts');
PHP

    # functions.php (с указанием авторства и лицензии)
    cat > "$THEME_DIR/functions.php" <<PHP
<?php
/**
 * Theme functions for $THEME_NAME
 *
 * Copyright (c) 2025 Constantine Mikhajlov <mikhajlov89@mail.ru>
 * Licensed under the GNU General Public License v2 or later
 */

// Подключаем инклуды
require_once __DIR__ . '/inc/enqueue.php';
require_once __DIR__ . '/inc/menu.php';
require_once __DIR__ . '/inc/cpts.php';

// Theme support
add_theme_support('title-tag');
add_theme_support('post-thumbnails');
add_theme_support('custom-logo');
add_theme_support('automatic-feed-links');

// Carbon Fields (автозагрузка, если установлено через composer)
if ( file_exists( __DIR__ . '/inc/composer/vendor/autoload.php' ) ) {
    require_once __DIR__ . '/inc/composer/vendor/autoload.php';
    \Carbon_Fields\Carbon_Fields::boot();
}
PHP

    # header.php
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

    # footer.php
    cat > "$THEME_DIR/footer.php" <<'PHP'
<footer>
  <p>&copy; <?php echo date('Y'); ?></p>
</footer>
<?php wp_footer(); ?>
</body>
</html>
PHP

    # index.php
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

    # пустые ассеты
    touch "$THEME_DIR/assets/css/main.css"
    touch "$THEME_DIR/assets/js/main.js"

    # style.css с обязательными заголовками (без ведущих отступов)
    cat > "$THEME_DIR/style.css" <<CSS
/*
Theme Name: $THEME_NAME
Theme URI: https://spaceweb.team/
Author: Constantine Mikhajlov
Author URI: mailto:mikhajlov89@mail.ru
Description: Тема WordPress для $THEME_NAME
Version: 1.0
License: GNU General Public License v2 or later
License URI: http://www.gnu.org/licenses/gpl-2.0.html
Text Domain: ${SAFE_NAME}
Tags: custom-theme

Copyright: (c) 2025 Constantine Mikhajlov <mikhajlov89@mail.ru>
*/
CSS

    echo "✅ Theme '$THEME_NAME' created at $THEME_DIR"
}

export -f create_theme_files
