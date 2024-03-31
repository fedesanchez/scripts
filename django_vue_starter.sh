#!/bin/bash

MSG=$(tput setaf 04)
SUCCESS=$(tput setaf 02)
WARN=$(tput setaf 01)
RESET=$(tput init)
DJANGO_VERSION=5.0.3
VITE_VERSION=5.1.7

if [ -z "$1" ]
  then
    echo "${WARN}No argument supplied: You need tu specify a project name.${RESET}"
    echo "Usage: ./django_vue_starter.sh SOME_PROJECT_NAME"
    exit 1
fi


if [ -d $1 ]
  then 
	echo "${WARN}Abort: $(pwd)/$1 already exists. Choose another project name or remove folder $1 first. ${RESET}"
	exit 1
fi

mkdir -p $1
cd $1

#Django project
echo "${MSG}#1 - Creating Django project.${RESET}"
python3 -m venv venv
source venv/bin/activate
pip install django==$DJANGO_VERSION
django-admin startproject core .
django-admin startapp app
pip install django_vite
pip install inertia-django

#settings
echo ""
echo "${MSG}#1.1 - Updating settings.py file.${RESET}"
sed -i "s/'django.contrib.staticfiles',/'django.contrib.staticfiles',\n    'inertia',\n    'django_vite',\n    'app',/g" ./core/settings.py
sed -i "s/'django.middleware.clickjacking.XFrameOptionsMiddleware',/'django.middleware.clickjacking.XFrameOptionsMiddleware',\n    'inertia.middleware.InertiaMiddleware',/g" ./core/settings.py
sed -i "s/'DIRS': \[\]/'DIRS': [BASE_DIR \/ 'templates']/g" ./core/settings.py

echo '
# Django-Vite config
DJANGO_VITE_ASSETS_PATH = BASE_DIR / "static" / "dist"
DJANGO_VITE_DEV_MODE = DEBUG
STATIC_ROOT = BASE_DIR / "collectedstatic"
STATICFILES_DIRS = [DJANGO_VITE_ASSETS_PATH]' >> ./core/settings.py

echo '
# Inertia config
INERTIA_LAYOUT = "base.html"
CSRF_HEADER_NAME = "HTTP_X_XSRF_TOKEN"
CSRF_COOKIE_NAME = "XSRF-TOKEN"' >> ./core/settings.py

#urls
echo ""
echo "${MSG}#1.2 - Updating urls.py.${RESET}"
sed -i "s/from django.urls import path/from django.urls import include, path/g" ./core/urls.py
sed -i "s/admin.site.urls),/admin.site.urls),\n    path('', include('app.urls'))/g" ./core/urls.py

echo '
from django.urls import path
from app import views

urlpatterns = [
    path("", views.index, name="index"),
]
' > ./app/urls.py

#views
echo ""
echo "${MSG}#1.3 - Adding example view.${RESET}"
echo '
from inertia import render

def index(request):
  return render(request, "Index", props={
    "content": "This content is a prop from django view!"
  })
' > ./app/views.py

# Templates
echo ""
echo "${MSG}#1.4 - Adding templates folder and base.html.${RESET}"
mkdir -p templates
echo '
{% load django_vite %}
{% vite_hmr_client %}
{% vite_asset "js/main.js" %}
<body>
    {% block inertia %}{% endblock %}
</body>
' > ./templates/base.html

pip freeze > requirements.txt
deactivate


#Vue+Vite+Inertia
echo ""
echo "${MSG}#2 - Adding vite + vue + inertia.${RESET}"
npm install vite@$VITE_VERSION vue @inertiajs/inertia @inertiajs/vue3 vite-plugin-dynamic-import @vitejs/plugin-vue

sed -i '2s/^/  "type": "module",\n/' package.json
sed -i '3s/^/  "scripts": {\n/' package.json
sed -i '4s/^/    "dev": "vite",\n/' package.json
sed -i '5s/^/    "build": "vite build",\n/' package.json
sed -i '6s/^/    "preview": "vite preview"\n/' package.json
sed -i '7s/^/  },\n/' package.json

echo ""
echo "${MSG}#2.1 - Creating vite.config.cjs.${RESET}"
echo 'import vue from "@vitejs/plugin-vue";
import dynaminImport from "vite-plugin-dynamic-import";
const { resolve } = require("path");

module.exports = {
	plugins: [vue(), dynaminImport()],
	root: resolve("./static/src"),
	base: "/static/",
	server: {
		host: "0.0.0.0",
		port: 5173,
		open: false,
		watch: {
			usePolling: true,
			disableGlobbing: false,
		},
	},
	resolve: {
		extensions: [".js", ".json", ".vue"],
		alias: {
			"@": resolve(__dirname, "./static/src/js"),
		},
	},
	build: {
		outDir: resolve("./static/dist"),
		assetsDir: "",
		manifest: true,
		emptyOutDir: true,
		target: "es2015",
		rollupOptions: {
			input: {
				main: resolve("./static/src/js/main.js"),
			},
			output: {
				chunkFileNames: "./static/src/js/[name].js?id=[chunkHash]",
			},
		},
	},
};' > vite.config.cjs

echo ""
echo "${MSG}#2.2 - Adding a basic Vue page.${RESET}"
mkdir -p static/src/js/components
mkdir -p static/src/js/pages
mkdir -p static/dist

echo '
import { createApp, h } from "vue";
import { createInertiaApp } from "@inertiajs/vue3";

createInertiaApp({
	resolve: (name) => {
		const pages = import.meta.glob("./pages/**/*.vue", { eager: true });
		return pages[`./pages/${name}.vue`];
	},
	setup({ el, App, props, plugin }) {
		createApp({ render: () => h(App, props) })
			.use(plugin)
			.mount(el);
	},
});' > static/src/js/main.js

echo '
<script setup>
defineProps({
  msg: {
    type: String,
    required: true
  }
})
</script>

<template>
  <div class="greetings">
    <h1 class="green">{{ msg }}</h1>
    <h3>
      You’ve successfully created a Django project with Vite + Vue + Inertia
    </h3>
  </div>
</template>
' > static/src/js/components/HelloWorld.vue

echo '
<script setup>
import HelloWorld from "@/components/HelloWorld.vue"
defineProps({
  content: {
    type: String,
    required: true
  }
})
</script>

<template>
  <header>    
    <div class="wrapper">
      <HelloWorld msg="You did it!" />
    </div>
  </header>
  <main>
    {{content}}
  </main>
</template>
' > static/src/js/pages/Index.vue

echo ""
echo "${SUCCESS} Done! You need to run npm run dev and ./manage.py runserver and go to http://localhost:8000 ${RESET}"