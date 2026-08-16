---
layout: default
title: Crypto Knowledge
permalink: /knowledge/
---
<div class="post-head">
  <div class="breadcrumb">home / knowledge</div>
  <h1>crypto knowledge</h1>
  <p style="color:var(--fg2);font-size:14px;margin-top:8px">
    Rangkuman serangan dan teori kripto, dipilah per topik. Klik kategori buat lihat isinya.
  </p>
</div>

{% assign kn_posts = site.posts | where:"platform","knowledge" %}

<div class="zone-grid">
  {% for cat in site.knowledge_cats %}
    {% assign cat_posts = kn_posts | where:"kn_cat",cat.slug %}
    <a class="zone" href="{{ '/knowledge/' | append: cat.slug | append: '/' | relative_url }}">
      <div class="num">{{ cat_posts.size }} catatan</div>
      <h3>{{ cat.name }}</h3>
      <p>{{ cat.desc }}</p>
      <span class="go">buka
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="14" height="14"><path d="M5 12h14M13 6l6 6-6 6"/></svg>
      </span>
    </a>
  {% endfor %}
</div>
