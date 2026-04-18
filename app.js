function switchTab(proto) {
  document.querySelectorAll('.protocol-tabs .tab').forEach(t => t.classList.remove('active'));
  event.target.classList.add('active');

  const baseMap = {
    https: 'https://linuxmirror.host',
    ftp:   'ftp://linuxmirror.host',
    rsync: 'rsync://linuxmirror.host',
  };

  document.querySelectorAll('.link-btn').forEach(btn => {
    const path = btn.dataset.path;
    btn.textContent = path;
    btn.href = baseMap[proto] + path;
    btn.dataset.proto = proto;
  });
}

function showConfig(distro) {
  document.querySelectorAll('.cfg-tab').forEach(t => t.classList.remove('active'));
  event.target.classList.add('active');
  document.querySelectorAll('.config-block').forEach(b => b.classList.remove('active'));
  document.getElementById('cfg-' + distro).classList.add('active');
}

// Animate bar fills on scroll
const observer = new IntersectionObserver(entries => {
  entries.forEach(e => {
    if (e.isIntersecting) {
      e.target.querySelectorAll('.bar-fill').forEach(bar => {
        const w = bar.style.width;
        bar.style.width = '0';
        requestAnimationFrame(() => { bar.style.width = w; });
      });
      observer.unobserve(e.target);
    }
  });
}, { threshold: 0.2 });

document.querySelectorAll('.bandwidth-info').forEach(el => observer.observe(el));

// Live "last sync" ticker — just cosmetic
setInterval(() => {
  const cells = document.querySelectorAll('.sync-ok');
  cells.forEach(cell => {
    const text = cell.textContent;
    const match = text.match(/(\d+)([mh]) ago/);
    if (!match) return;
    let val = parseInt(match[1]);
    const unit = match[2];
    if (unit === 'm' && Math.random() < 0.03) {
      val = Math.min(val + 1, 59);
      cell.textContent = val + 'm ago';
    }
  });
}, 60000);
