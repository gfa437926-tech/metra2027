// enhanced-validation.js - نظام التحقق المحسن مع دعم # وتحديث حقول الضغط عند 00
console.log('🔍 تحميل نظام التحقق المحسن (نسخة معدلة)');

class EnhancedValidation {
    constructor() { this.init(); }
    init() {
        this.setupAutoFormatting();
        this.setupValidation();
        this.setupTemperatureValidation();
        this.setupForceFormatting();
        this.setupFieldRelationships();
        this.setupAutoCompletionOnBlur();
        this.allowHashInAllFields();
        console.log('✅ نظام التحقق من المدخلات جاهز');
    }
    setupAutoFormatting() {
        const inputs = document.querySelectorAll('input[type="text"], .input-mask, .temperature-input, .pressure-input');
        inputs.forEach(field => {
            if (field.classList.contains('cloud-type-input') || field.readOnly) return;
            field.addEventListener('input', e => this.formatWhileTyping(e.target));
            field.addEventListener('blur', e => this.forceCompleteFormatting(e.target));
            field.addEventListener('keypress', e => { if (e.key === 'Enter') { e.preventDefault(); this.forceCompleteFormatting(e.target); this.focusNextField(e.target); } });
            field.addEventListener('keydown', e => { if (e.key === '#') { e.preventDefault(); this.applyHashToField(e.target); } });
        });
    }
    allowHashInAllFields() {
        document.querySelectorAll('input, textarea').forEach(input => {
            input.addEventListener('input', e => this.handleHashInput(e.target));
            input.addEventListener('keydown', e => { if (e.key === '#') this.applyHashToField(e.target); });
        });
    }
    handleHashInput(field) {
        if (field.value.includes('#')) { field.value = '#'; field.classList.add('has-hash'); }
        else if (field.value !== '#') field.classList.remove('has-hash');
    }
    applyHashToField(field) {
        field.value = '#'; field.classList.add('has-hash'); field.classList.remove('is-invalid'); field.classList.add('is-valid');
        let err = document.getElementById(field.id + 'Error'); if (err) err.style.display = 'none';
        let suc = document.getElementById(field.id + 'Success'); if (suc) { suc.textContent = 'بيانات غير متوفرة (#)'; suc.style.display = 'block'; }
    }
    forceCompleteFormatting(field) {
        if (!field || field.value === '#') return;
        let v = field.value.trim();
        if (!v) return;
        this.completeFormatting(field);
        this.validateField(field);
    }
    completeFormatting(field) {
        if (!field || field.disabled) return;
        let v = field.value.trim();
        if (!v || v === '#') return;
        let id = field.id;
        if (field.classList.contains('cloud-type-input')) return;
        if (id.includes('Temp') || id === 'dewPoint') this.formatTemperature(field, v);
        else if (id === 'relativeHumidity') this.formatHumidity(field, v);
        else if (id.includes('windDirection')) this.formatWindDirection(field, v);
        else if (id.includes('windSpeed')) this.formatWindSpeed(field, v);
        else if (id === 'visibility') this.formatVisibility(field, v);
        else if (id === 'stationPressure' || id === 'seaLevelPressure') this.formatPressure(field, v);
        else if (id === 'vaporPressure' || id === 'vaporPressureDiff') this.formatVaporPressure(field, v);
        else if (id === 'pressureSlope') this.formatPressureSlope(field, v);
        else if (id === 'precipitationAmount') this.formatPrecipitation(field, v);
        else if (id === 'currentWeather') this.formatCurrentWeather(field, v);
        else if (id === 'pastWeather') this.formatPastWeather(field, v);
        else if (id.includes('Height')) this.formatCloudHeight(field, v);
        else if (id === 'utcTime') this.formatUTCTime(field, v);
        else if (field.classList.contains('input-mask')) this.formatGeneralNumeric(field, v);
    }
    formatTemperature(field, value) {
        if (value === '#') return;
        let f = value.replace(/[^0-9.\-+]/g, '');
        if (!f.startsWith('+') && !f.startsWith('-')) f = '+' + f;
        f = f.replace(/([+-])(.*?)([+-])/g, '$1$2');
        if (!f.includes('.')) {
            let sign = f.startsWith('-') ? '-' : '+';
            let num = f.replace(/[^0-9]/g, '');
            if (num.length === 1) f = sign + '0' + num + '.0';
            else if (num.length === 2) f = sign + num + '.0';
            else if (num.length > 2) f = sign + num.substring(0, 2) + '.' + num.substring(2, 3);
        } else {
            let parts = f.split('.');
            let sign = parts[0].startsWith('-') ? '-' : '+';
            let intPart = parts[0].replace(/[^0-9]/g, '');
            let decPart = parts[1]?.replace(/[^0-9]/g, '') || '';
            if (decPart.length > 1) decPart = decPart.charAt(0);
            if (intPart.length === 1) f = sign + '0' + intPart + '.' + (decPart || '0');
            else if (intPart.length === 2) f = sign + intPart + '.' + (decPart || '0');
            else f = sign + intPart.substring(0, 2) + '.' + (decPart || '0');
        }
        field.value = f;
    }
    formatHumidity(field, value) { if (value === '#') return; let f = value.replace(/[^0-9]/g, ''); if (f.length === 1) f = '00' + f; else if (f.length === 2) f = '0' + f; if (parseInt(f) > 100) f = '100'; field.value = f; }
    formatWindDirection(field, value) { if (value === '#') return; let f = value.replace(/[^0-9]/g, ''); if (f.length === 1) f = '0' + f; if (parseInt(f) > 36) f = '36'; field.value = f; }
    formatWindSpeed(field, value) { if (value === '#') return; let f = value.replace(/[^0-9]/g, ''); if (f.length === 1) f = '0' + f; if (parseInt(f) > 99) f = '99'; field.value = f; }
    formatVisibility(field, value) { if (value === '#') return; let f = value.replace(/[^0-9]/g, ''); if (f.length === 1) f = '00' + f; else if (f.length === 2) f = '0' + f; if (parseInt(f) > 200) f = '200'; field.value = f; }
    formatPressure(field, value) { if (value === '#') return; let f = value.replace(/[^0-9.]/g, ''); if (!f.includes('.')) { if (f.length === 1) f = '000' + f + '.0'; else if (f.length === 2) f = '00' + f + '.0'; else if (f.length === 3) f = '0' + f + '.0'; else if (f.length === 4) f = f + '.0'; else f = f.substring(0, 4) + '.0'; } else { let parts = f.split('.'); let num = parts[0].replace(/[^0-9]/g, ''); let dec = parts[1] || ''; if (num.length === 1) num = '000' + num; else if (num.length === 2) num = '00' + num; else if (num.length === 3) num = '0' + num; if (dec.length === 0) dec = '0'; else if (dec.length > 1) dec = dec.charAt(0); f = num + '.' + dec; } field.value = f; }
    formatVaporPressure(field, value) { if (value === '#') return; let f = value.replace(/[^0-9.]/g, ''); if (!f.includes('.')) { if (f.length === 1) f = '0' + f + '.0'; else if (f.length === 2) f = f + '.0'; else f = f.substring(0, 2) + '.0'; } else { let parts = f.split('.'); let int = parts[0].replace(/[^0-9]/g, ''); let dec = parts[1] || ''; if (int.length === 1) int = '0' + int; else if (int.length > 2) int = int.substring(0, 2); if (dec.length === 0) dec = '0'; else if (dec.length > 1) dec = dec.charAt(0); f = int + '.' + dec; } field.value = f; }
    formatPressureSlope(field, value) { if (value === '#') return; let f = value.replace(/[^0-9.]/g, ''); if (!f.includes('.')) { if (f.length === 1) f = f + '.0'; else if (f.length === 2) f = f + '.0'; else f = f.substring(0, 2) + '.' + f.substring(2, 3); } else { let parts = f.split('.'); let int = parts[0].replace(/[^0-9]/g, '') || '0'; let dec = parts[1] || ''; if (dec.length > 1) dec = dec.charAt(0); f = int + '.' + (dec || '0'); } field.value = f; }
    formatPrecipitation(field, value) { if (value === '#') return; let f = value.replace(/[^0-9.]/g, ''); if (!f.includes('.')) { if (f.length === 1) f = '00' + f + '.0'; else if (f.length === 2) f = '0' + f + '.0'; else if (f.length === 3) f = f + '.0'; else f = f.substring(0, 3) + '.0'; } else { let parts = f.split('.'); let int = parts[0].replace(/[^0-9]/g, ''); let dec = parts[1] || ''; if (int.length === 1) int = '00' + int; else if (int.length === 2) int = '0' + int; else if (int.length > 3) int = int.substring(0, 3); if (dec.length === 0) dec = '0'; else if (dec.length > 1) dec = dec.charAt(0); f = int + '.' + dec; } field.value = f; }
    formatCurrentWeather(field, value) { if (value === '#') return; let f = value.replace(/[^0-9]/g, ''); if (f.length === 1) f = '0' + f; else if (f.length > 2) f = f.substring(0, 2); if (parseInt(f) > 99) f = '99'; field.value = f; }
    formatPastWeather(field, value) { if (value === '#') return; let f = value.replace(/[^0-9]/g, ''); if (f.length > 1) f = f.charAt(0); if (parseInt(f) > 9) f = '9'; field.value = f; }
    formatCloudHeight(field, value) { if (value === '#') return; let f = value.replace(/[^0-9]/g, ''); if (f.length === 1) f = '00' + f; else if (f.length === 2) f = '0' + f; if (parseInt(f) > 999) f = '999'; field.value = f; }
    formatGeneralNumeric(field, value) { if (value === '#') return; field.value = value.replace(/[^0-9]/g, ''); }
    formatUTCTime(field, value) { if (value === '#') return; let f = value.replace(/[^0-9]/g, ''); if (f.length === 1) f = '0' + f; else if (f.length > 2) f = f.substring(0, 2); if (parseInt(f) > 23) f = '23'; field.value = f; }
    formatWhileTyping(field) {
        let v = field.value;
        if (v === '#') { field.classList.add('has-hash'); return; }
        field.classList.remove('has-hash');
        if (field.id.includes('Temp') || field.id === 'dewPoint') {
            if (v.endsWith('+') || v.endsWith('-')) { let s = v.slice(-1); let n = v.slice(0, -1); field.value = s + n; }
            else if (v.length > 0 && !v.startsWith('+') && !v.startsWith('-')) field.value = '+' + v;
            if (field.value.includes('-')) field.classList.add('negative-value'); else field.classList.remove('negative-value');
        }
        let allowed = (field.id.includes('Temp') || field.id === 'dewPoint') ? /[^0-9.\-+#]/g : /[^0-9.#]/g;
        let cleaned = v.replace(allowed, '');
        if (cleaned !== v) field.value = cleaned;
    }
    validateField(field) {
        if (!field) return true;
        let v = field.value.trim();
        if (v === '#') { this.showSuccess(field); return true; }
        if (field.id === 'pastWeather' && !this.isPastWeatherRequired()) { this.showSuccess(field); return true; }
        if (!v && field.required) { this.showError(field, 'هذا الحقل مطلوب'); return false; }
        let range = this.checkRange(field.id, v);
        if (!range.valid) { this.showError(field, range.message); return false; }
        let format = this.checkFormat(field.id, v);
        if (!format.valid) { this.showError(field, format.message); return false; }
        this.showSuccess(field);
        return true;
    }
    checkRange(id, val) { if (val === '#') return { valid: true }; const ranges = { dryTemp: { min: -20, max: 50, type: 'float' }, wetTemp: { min: -20, max: 50, type: 'float' }, dewPoint: { min: -20, max: 50, type: 'float' }, stationPressure: { min: 850, max: 1050, type: 'float' }, seaLevelPressure: { min: 0, max: 1050, type: 'float' }, relativeHumidity: { min: 1, max: 100, type: 'int' }, windDirection: { min: 0, max: 36, type: 'int' }, windSpeed: { min: 0, max: 99, type: 'int' }, avgWindSpeed: { min: 0, max: 99, type: 'int' }, visibility: { min: 0, max: 200, type: 'int' }, vaporPressure: { min: 0, max: 99, type: 'float' }, pressureSlope: { min: 0, max: 99, type: 'float' }, pastWeather: { min: 0, max: 9, type: 'int' }, currentWeather: { min: 0, max: 99, type: 'int' }, utcTime: { min: 0, max: 23, type: 'int' } }; let r = ranges[id]; if (!r) return { valid: true }; let num = r.type === 'float' ? parseFloat(val) : parseInt(val); if (isNaN(num)) return { valid: false, message: 'قيمة غير صحيحة' }; if (num < r.min || num > r.max) return { valid: false, message: `يجب أن تكون بين ${r.min} و ${r.max}` }; return { valid: true }; }
    checkFormat(id, val) { if (val === '#') return { valid: true }; const patterns = { dryTemp: /^[+-]\d{2}\.\d$/, wetTemp: /^[+-]\d{2}\.\d$/, dewPoint: /^[+-]\d{2}\.\d$/, relativeHumidity: /^\d{3}$/, windDirection: /^\d{2}$/, windSpeed: /^\d{2}$/, avgWindSpeed: /^\d{2}$/, visibility: /^\d{3}$/, vaporPressure: /^\d{2}\.\d$/, pressureSlope: /^\d{1,2}\.\d$/, pastWeather: /^\d{1}$/, currentWeather: /^\d{2}$/, utcTime: /^\d{2}$/ }; let p = patterns[id]; if (!p) return { valid: true }; if (!p.test(val)) return { valid: false, message: 'التنسيق غير صحيح' }; return { valid: true }; }
    validateTemperatureRelationship() { let d = document.getElementById('dryTemp')?.value.trim(), w = document.getElementById('wetTemp')?.value.trim(); if (!d || !w || d === '#' || w === '#') return true; let dn = parseFloat(d), wn = parseFloat(w); if (isNaN(dn) || isNaN(wn)) return true; if (dn < wn) { this.showError(document.getElementById('dryTemp'), 'الحرارة الجافة يجب أن تكون ≥ الحرارة الرطبة'); this.showError(document.getElementById('wetTemp'), 'الحرارة الرطبة يجب أن تكون ≤ الحرارة الجافة'); return false; } return true; }
    showSuccess(f) { if (!f) return; f.classList.remove('is-invalid'); f.classList.add('is-valid'); let e = document.getElementById(f.id + 'Error'); if (e) e.style.display = 'none'; let s = document.getElementById(f.id + 'Success'); if (s) s.style.display = 'block'; }
    showError(f, m) { if (!f) return; f.classList.remove('is-valid'); f.classList.add('is-invalid'); let e = document.getElementById(f.id + 'Error'); if (e) { e.textContent = m; e.style.display = 'block'; } }
    focusNextField(f) { let form = document.getElementById('hourlyReportForm'); if (!form) return; let fields = Array.from(form.querySelectorAll('input:not([readonly]):not([disabled]), select:not([disabled])')); let idx = fields.indexOf(f); if (idx > -1 && idx < fields.length - 1) fields[idx + 1].focus(); }
    setupForceFormatting() { window.forceFormatAllFields = () => this.forceFormatAllFields(); }
    forceFormatAllFields() { document.querySelectorAll('input[type="text"]:not([readonly])').forEach(f => { if (!f.classList.contains('cloud-type-input')) this.forceCompleteFormatting(f); }); }
    isPastWeatherRequired() { let u = document.getElementById('utcTime'); if (!u || !u.value) return false; let h = u.value.padStart(2, '0'); return ['03', '06', '09', '12', '15', '18', '21', '00'].includes(h); }
    updatePastWeatherRequirement() { let f = document.getElementById('pastWeather'); if (!f) return; let req = this.isPastWeatherRequired(); f.required = req; let card = f.closest('.card-field'); if (card) card.style.display = req ? 'block' : 'none'; if (!req) f.value = ''; }
    updateTimeDependentFields() {
        let u = document.getElementById('utcTime');
        if (!u || !u.value) return;
        let h = u.value.padStart(2, '0');
        let p = document.getElementById('precipitationFields');
        if (p) p.classList.toggle('active', ['00', '06', '12', '18'].includes(h));
        // ✅ التعديل: إضافة '00' إلى الساعات التي تظهر فيها حقول ميل الضغط
        let ps = document.getElementById('pressureSlopeFields');
        if (ps) ps.classList.toggle('active', ['00', '03', '06', '09', '12', '15', '18', '21'].includes(h));
    }
    setupFieldRelationships() { ['dryTemp', 'wetTemp', 'dewPoint'].forEach(id => { let f = document.getElementById(id); if (f) f.addEventListener('blur', () => this.validateTemperatureRelationship()); }); }
    setupTemperatureValidation() { this.setupFieldRelationships(); }
    setupValidation() { this.setupFieldRelationships(); let u = document.getElementById('utcTime'); if (u) u.addEventListener('change', () => { this.updatePastWeatherRequirement(); this.updateTimeDependentFields(); }); }
}

document.addEventListener('DOMContentLoaded', () => { setTimeout(() => { try { window.enhancedValidation = new EnhancedValidation(); } catch (e) { console.error(e); } }, 500); });