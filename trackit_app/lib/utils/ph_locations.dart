/// Provinces and their cities / municipalities for the company address
/// dropdowns (Account Details Finalization). Covers CALABARZON and Metro
/// Manila, where most PLSP OJT placements are; anything else can be typed
/// in with the "Other" option. Barangays are typed in (no official list
/// is bundled yet).
const Map<String, List<String>> phCitiesByProvince = {
  'Laguna': [
    'Alaminos', 'Bay', 'Biñan City', 'Cabuyao City', 'Calamba City', 'Calauan', 'Cavinti',
    'Famy', 'Kalayaan', 'Liliw', 'Los Baños', 'Luisiana', 'Lumban', 'Mabitac', 'Magdalena',
    'Majayjay', 'Nagcarlan', 'Paete', 'Pagsanjan', 'Pakil', 'Pangil', 'Pila', 'Rizal',
    'San Pablo City', 'San Pedro City', 'Santa Cruz', 'Santa Maria', 'Santa Rosa City',
    'Siniloan', 'Victoria',
  ],
  'Batangas': [
    'Agoncillo', 'Alitagtag', 'Balayan', 'Balete', 'Batangas City', 'Bauan', 'Calaca City',
    'Calatagan', 'Cuenca', 'Ibaan', 'Laurel', 'Lemery', 'Lian', 'Lipa City', 'Lobo', 'Mabini',
    'Malvar', 'Mataasnakahoy', 'Nasugbu', 'Padre Garcia', 'Rosario', 'San Jose', 'San Juan',
    'San Luis', 'San Nicolas', 'San Pascual', 'Santa Teresita', 'Santo Tomas City', 'Taal',
    'Talisay', 'Tanauan City', 'Taysan', 'Tingloy', 'Tuy',
  ],
  'Cavite': [
    'Alfonso', 'Amadeo', 'Bacoor City', 'Carmona City', 'Cavite City', 'Dasmariñas City',
    'General Emilio Aguinaldo', 'General Mariano Alvarez', 'General Trias City', 'Imus City',
    'Indang', 'Kawit', 'Magallanes', 'Maragondon', 'Mendez', 'Naic', 'Noveleta', 'Rosario',
    'Silang', 'Tagaytay City', 'Tanza', 'Ternate', 'Trece Martires City',
  ],
  'Quezon': [
    'Agdangan', 'Alabat', 'Atimonan', 'Buenavista', 'Burdeos', 'Calauag', 'Candelaria',
    'Catanauan', 'Dolores', 'General Luna', 'General Nakar', 'Guinayangan', 'Gumaca', 'Infanta',
    'Jomalig', 'Lopez', 'Lucban', 'Lucena City', 'Macalelon', 'Mauban', 'Mulanay',
    'Padre Burgos', 'Pagbilao', 'Panukulan', 'Patnanungan', 'Perez', 'Pitogo', 'Plaridel',
    'Polillo', 'Quezon', 'Real', 'Sampaloc', 'San Andres', 'San Antonio', 'San Francisco',
    'San Narciso', 'Sariaya', 'Tagkawayan', 'Tayabas City', 'Tiaong', 'Unisan',
  ],
  'Rizal': [
    'Angono', 'Antipolo City', 'Baras', 'Binangonan', 'Cainta', 'Cardona', 'Jalajala', 'Morong',
    'Pililla', 'Rodriguez', 'San Mateo', 'Tanay', 'Taytay', 'Teresa',
  ],
  'Metro Manila': [
    'Caloocan City', 'Las Piñas City', 'Makati City', 'Malabon City', 'Mandaluyong City',
    'Manila', 'Marikina City', 'Muntinlupa City', 'Navotas City', 'Parañaque City', 'Pasay City',
    'Pasig City', 'Pateros', 'Quezon City', 'San Juan City', 'Taguig City', 'Valenzuela City',
  ],
};

const String otherLocation = 'Other (type it)';

/// Industry choices for the company (matches the HTE Directory chips).
const List<String> companyIndustries = [
  'Education',
  'Government',
  'Healthcare',
  'Information Technology',
  'BPO / Call Center',
  'Banking & Finance',
  'Telecommunications',
  'Media & Broadcasting',
  'Manufacturing',
  'Retail / Grocery',
  'Hospitality & Food Service',
  'Logistics',
  'Engineering & Construction',
  'Non-Profit / NGO',
  'Other',
];
