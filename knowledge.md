---
layout: default
title: Crypto Knowledge
permalink: /knowledge/
---
<div class="post-head">
  <div class="breadcrumb">home / knowledge</div>
  <h1>crypto knowledge</h1>
  <p style="color:var(--fg2);font-size:14px;margin-top:8px">
    <span class="lang-en">Crypto attack and theory notes, split by topic. Click a category to see its content.</span>
    <span class="lang-id">Rangkuman serangan dan teori kripto, dipilah per topik. Klik kategori buat lihat isinya.</span>
  </p>
</div>

{% assign kn_posts = site.posts | where:"platform","knowledge" %}

{% assign zcolors = "zc-green,zc-teal,zc-lime,zc-emerald,zc-cyan,zc-gold" | split: "," %}
<div class="zone-grid">
  {% for cat in site.knowledge_cats %}
    {% assign cat_posts = kn_posts | where:"kn_cat",cat.slug %}
    {% assign zidx = forloop.index0 | modulo: 6 %}
    {% assign zc = zcolors[zidx] %}
    <a class="zone {{ zc }}" href="{{ '/knowledge/' | append: cat.slug | append: '/' | relative_url }}">
      <div class="num">{{ cat_posts.size }} <span class="lang-en">notes</span><span class="lang-id">catatan</span></div>
      <h3>{{ cat.name }}</h3>
      <p><span class="lang-en">{{ cat.desc_en }}</span><span class="lang-id">{{ cat.desc_id }}</span></p>
      <span class="go"><span class="lang-en">open</span><span class="lang-id">buka</span>
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="14" height="14"><path d="M5 12h14M13 6l6 6-6 6"/></svg>
      </span>
    </a>
  {% endfor %}
</div>

<div class="sec-title">
  <h2><span class="lang-en">browse by tag</span><span class="lang-id">jelajah per tag</span></h2>
  <span class="cmd">$ ls ~/knowledge --tag</span>
  <span class="rule"></span>
</div>
<p style="color:var(--fg3);font-size:12.5px;margin:-6px 0 var(--sp3)">
  <span class="lang-en">Click a tag to filter notes below (e.g. ecdsa, lattice, hnp). Click again to reset.</span>
  <span class="lang-id">Klik satu tag buat filter catatan di bawah (misal ecdsa, lattice, hnp). Klik lagi buat reset.</span>
</p>

{% assign all_tags = "" | split: "" %}
{% for p in kn_posts %}{% for t in p.tags %}{% assign all_tags = all_tags | push: t %}{% endfor %}{% endfor %}
{% assign uniq_tags = all_tags | uniq | sort %}

<div class="tagcloud" id="kn-tagcloud">
  <a href="#" class="tag-filter active" data-tag="">
    <span class="lang-en">all</span><span class="lang-id">semua</span>
    <span class="cnt">({{ kn_posts.size }})</span>
  </a>
  {% for t in uniq_tags %}
    {% assign tcount = 0 %}
    {% for p in kn_posts %}{% if p.tags contains t %}{% assign tcount = tcount | plus: 1 %}{% endif %}{% endfor %}
    <a href="#" class="tag-filter" data-tag="{{ t }}">{{ t }} <span class="cnt">({{ tcount }})</span></a>
  {% endfor %}
</div>

{% assign n_en = 0 %}{% assign n_id = 0 %}
{% for p in kn_posts %}{% assign pl = p.lang | default: "id" %}{% if pl == "en" %}{% assign n_en = n_en | plus: 1 %}{% else %}{% assign n_id = n_id | plus: 1 %}{% endif %}{% endfor %}

<div class="sec-title">
  <h2><span class="lang-en">all notes</span><span class="lang-id">semua catatan</span></h2>
  <span class="cmd">$ ls ~/knowledge</span>
  <span class="rule"></span>
</div>

{% assign langs = "en,id" | split: "," %}
{% for L in langs %}
  {% if L == "en" %}{% assign lc = n_en %}{% else %}{% assign lc = n_id %}{% endif %}
  <div class="plang-{{ L }}">
  {% if lc == 0 %}
  <div class="empty">
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.4"><path d="M4 19.5A2.5 2.5 0 0 1 6.5 17H20"/><path d="M6.5 2H20v20H6.5A2.5 2.5 0 0 1 4 19.5v-15A2.5 2.5 0 0 1 6.5 2z"/></svg>
    <div class="t">{% if L == "en" %}no notes yet{% else %}belum ada catatan{% endif %}</div>
  </div>
  {% else %}
  <div id="kn-list-{{ L }}">
    {% for post in kn_posts %}{% assign pl = post.lang | default: "id" %}{% if pl == L %}
    {% assign kcat = site.knowledge_cats | where:"slug",post.kn_cat | first %}
    <div class="post-item kn-item" data-tags=",{{ post.tags | join: ',' }},">
      <div class="meta">
        {{ post.date | date: "%d %b %Y" }}
        {% if kcat %} :: <span class="cat">{{ kcat.name }}</span>{% endif %}
      </div>
      <h2><a href="{{ post.url | relative_url }}">{{ post.title }}</a></h2>
      {% if post.description %}<p>{{ post.description }}</p>{% else %}<p>{{ post.excerpt | strip_html | truncatewords: 26 }}</p>{% endif %}
      {% if post.tags %}
      <div class="tags">
        {% for tag in post.tags %}<span class="tag-chip">{{ tag }}</span>{% endfor %}
      </div>
      {% endif %}
    </div>
    {% endif %}{% endfor %}
  </div>
  {% endif %}
  </div>
{% endfor %}

<div class="empty kn-empty-filter" id="kn-empty-filter" style="display:none">
  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.4"><circle cx="11" cy="11" r="7"/><path d="m21 21-4.3-4.3"/></svg>
  <div class="t"><span class="lang-en">no notes with this tag</span><span class="lang-id">belum ada catatan dengan tag ini</span></div>
</div>

<script>
(function(){
  var cloud = document.getElementById('kn-tagcloud');
  if (!cloud) return;
  var buttons = cloud.querySelectorAll('.tag-filter');
  var items = document.querySelectorAll('.kn-item');
  var emptyMsg = document.getElementById('kn-empty-filter');

  function applyFilter(tag){
    var visibleCount = 0;
    items.forEach(function(el){
      var show = !tag || el.getAttribute('data-tags').indexOf(',' + tag + ',') !== -1;
      el.style.display = show ? '' : 'none';
      if (show) visibleCount++;
    });
    if (emptyMsg) emptyMsg.style.display = visibleCount === 0 ? '' : 'none';
  }

  buttons.forEach(function(btn){
    btn.addEventListener('click', function(e){
      e.preventDefault();
      var tag = btn.getAttribute('data-tag');
      var wasActive = btn.classList.contains('active');
      buttons.forEach(function(b){ b.classList.remove('active'); });
      if (tag === '' || wasActive) {
        cloud.querySelector('.tag-filter[data-tag=""]').classList.add('active');
        applyFilter('');
      } else {
        btn.classList.add('active');
        applyFilter(tag);
      }
    });
  });
})();
</script>
