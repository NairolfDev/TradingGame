"""Refresh the committed symbol catalog from official public sources.
Run from repository root: python tools/update_stock_catalog.py
Update stock_catalog_sources.json DAX URL for the latest public review first.
Unknown new European ISINs fail rather than silently guess Yahoo symbols.
No downloaded prices are used as quotes or seed values.
"""
import csv
import datetime
import gzip
import html
import io
import json
import re
import urllib.request
from pathlib import Path

DAX_SYMBOLS = {'DE0007236101': 'SIE.DE', 'DE0007164600': 'SAP.DE', 'DE0008404005': 'ALV.DE', 'DE000ENER6Y0': 'ENR.DE', 'NL0000235190': 'AIR.DE', 'DE0005557508': 'DTE.DE', 'DE0006231004': 'IFX.DE', 'DE0008430026': 'MUV2.DE', 'DE0005140008': 'DBK.DE', 'DE0005552004': 'DHL.DE', 'DE0005810055': 'DB1.DE', 'DE000BAY0017': 'BAYN.DE', 'DE0007030009': 'RHM.DE', 'DE000BASF111': 'BAS.DE', 'DE0007037129': 'RWE.DE', 'DE000ENAG999': 'EOAN.DE', 'DE0007100000': 'MBG.DE', 'DE000A1EWWW0': 'ADS.DE', 'DE000DTR0CK8': 'DTG.DE', 'DE0005190003': 'BMW.DE', 'DE0006047004': 'HEI.DE', 'DE000A0D9PT0': 'MTX.DE', 'DE000FRE5EN2': 'FRE.DE', 'DE0006599905': 'MRK.DE', 'DE000CBK1001': 'CBK.DE', 'DE0007664039': 'VOW3.DE', 'DE0008402215': 'HNR1.DE', 'DE000SHL1006': 'SHL.DE', 'DE000A1ML7J1': 'VNA.DE', 'DE000SYM9999': 'SY1.DE', 'DE0006048432': 'HEN3.DE', 'DE0006602006': 'G1A.DE', 'DE0005785802': 'FME.DE', 'NL0015002SN0': 'QIA.DE', 'DE0005439004': 'CON.DE', 'DE0006070006': 'HOT.DE', 'DE000A1DAHH0': 'BNR.DE', 'DE0005200000': 'BEI.DE', 'DE000ZAL1111': 'ZAL.DE', 'DE000A12DM80': 'G24.DE'}
ATX_SYMBOLS = {'AT0000652011': 'EBS.VI', 'AT0000BAWAG2': 'BG.VI', 'AT0000743059': 'OMV.VI', 'AT0000606306': 'RBI.VI', 'AT0000730007': 'ANDR.VI', 'AT0000937503': 'VOE.VI', 'AT0000969985': 'ATS.VI', 'AT0000746409': 'VER.VI', 'AT000000STR1': 'STR.VI', 'AT0000908504': 'VIG.VI', 'AT0000821103': 'UQA.VI', 'AT0000831706': 'WIE.VI', 'AT0000741053': 'EVN.VI', 'AT0000818802': 'DOC.VI', 'AT0000APOST4': 'POST.VI', 'AT0000641352': 'CAI.VI', 'AT0000609607': 'POS.VI', 'AT0000938204': 'MMK.VI', 'AT0000758305': 'PAL.VI', 'AT0000644505': 'LNZ.VI'}
SECTORS = {'Technology': 'Technologie', 'Finance': 'Finanzen', 'Financials': 'Finanzen',
 'Health Care': 'Gesundheit', 'Healthcare': 'Gesundheit', 'Industrials': 'Industrie',
 'Consumer Discretionary': 'Zyklischer Konsum', 'Consumer Staples': 'Basiskonsum',
 'Energy': 'Energie', 'Utilities': 'Versorger', 'Basic Materials': 'Grundstoffe',
 'Real Estate': 'Immobilien', 'Telecommunications': 'Kommunikation', 'Miscellaneous': 'Sonstige',
 'Capital Goods/Others': 'Industrie', 'Materials': 'Grundstoffe', 'Consumer Goods': 'Konsum',
 'Information and Communications': 'Kommunikation'}

def fetch(url, encoding='utf-8-sig'):
    request = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0', 'Accept': 'text/csv,*/*'})
    data = urllib.request.urlopen(request, timeout=30).read()
    if data[:2] == b'\x1f\x8b':
        data = gzip.decompress(data)
    return data.decode(encoding)

def main():
    manifest_path = Path('tools/stock_catalog_sources.json')
    manifest = json.loads(manifest_path.read_text())
    sources = manifest['sources']
    today = datetime.date.today().isoformat()
    metadata = {r['symbol']: r for r in json.loads(fetch(sources['Nasdaq metadata']['url']))['data']['rows']}
    rows = []
    for record in csv.DictReader(io.StringIO(fetch(sources['Nasdaq']['url'])), delimiter='|'):
        if any(record.get(k) != 'N' for k in ['Test Issue', 'ETF', 'NextShares']):
            continue
        name = record['Security Name']
        instrument = name.split(' - ')[-1]
        if re.search(r'\b(warrants?|units?|rights?|notes?|debentures?|bonds?|ETF|ETN)\b', instrument, re.I):
            continue
        extra = metadata.get(record['Symbol'], {})
        sector = extra.get('sector') or 'Unbekannt'
        rows.append([record['Symbol'], name.split(' - ')[0], 'Nasdaq', SECTORS.get(sector, sector),
                     extra.get('industry', ''), extra.get('country', ''), today])
    dax = [r for r in csv.DictReader(io.StringIO(fetch(sources['DAX']['url'])), delimiter=';')
           if r['Index Membership'] == 'DAXK']
    assert len(dax) == 40
    for record in dax:
        stamp = datetime.datetime.strptime(record['Creation_Date'], '%Y%m%d').date().isoformat()
        rows.append([DAX_SYMBOLS[record['ISIN']], record['Instrument_Name'], 'DAX', 'Unbekannt', '', 'DE', stamp])
    atx = re.findall(r'data-value="([A-Z0-9]{12})" data-name="([^"]+)"', fetch(sources['ATX']['url']))
    assert len(atx) == 20
    for isin, name in atx:
        rows.append([ATX_SYMBOLS[isin], html.unescape(name), 'ATX', 'Unbekannt', '', 'AT', today])
    nikkei = [r for r in csv.DictReader(io.StringIO(fetch(sources['Nikkei 225']['url'], 'cp932'))) if r.get('Code')]
    assert len(nikkei) == 225
    for record in nikkei:
        rows.append([record['Code'] + '.T', record['Company Name'], 'Nikkei 225',
                     SECTORS.get(record['Sector'], record['Sector']), record['Nikkei Industrial Classification'],
                     'JP', record['Date of Data'].replace('/', '-')])
    assert len({r[0] for r in rows}) == len(rows)
    output = '// Generated from official sources; see tools/stock_catalog_sources.json.\nconst stockCatalogRows = <List<String>>[\n'
    output += ''.join('  ' + json.dumps(row, ensure_ascii=False).replace('$', '\\$') + ',\n' for row in rows)
    output += '];\n'
    Path('lib/data/catalog/stock_catalog_data.dart').write_text(output, encoding='utf-8')
    manifest['generatedAt'] = today
    manifest['counts'] = {group: sum(r[2] == group for r in rows) for group in ['Nasdaq', 'DAX', 'ATX', 'Nikkei 225']}
    for group in manifest['counts']:
        sources[group]['asOf'] = max(r[6] for r in rows if r[2] == group)
    sources['Nasdaq metadata']['asOf'] = today
    manifest_path.write_text(json.dumps(manifest, indent=2), encoding='utf-8')
    print(manifest['counts'])

if __name__ == '__main__':
    main()
