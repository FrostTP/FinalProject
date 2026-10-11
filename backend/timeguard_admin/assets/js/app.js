'use strict';
document.querySelectorAll('[data-print]').forEach(b=>b.addEventListener('click',()=>window.print()));
document.querySelectorAll('form[data-confirm]').forEach(f=>f.addEventListener('submit',ev=>{if(!window.confirm(f.dataset.confirm))ev.preventDefault();}));
