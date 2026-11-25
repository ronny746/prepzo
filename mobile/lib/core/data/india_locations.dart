/// Curated state/city choices used in profile and registration forms.
/// Keeping this local makes registration reliable even when offline.
const Map<String, List<String>> indiaCitiesByState = {
  'Andhra Pradesh': ['Visakhapatnam', 'Vijayawada', 'Guntur', 'Tirupati'],
  'Assam': ['Guwahati', 'Dibrugarh', 'Silchar'],
  'Bihar': ['Patna', 'Gaya', 'Muzaffarpur', 'Bhagalpur'],
  'Chhattisgarh': ['Raipur', 'Bhilai', 'Bilaspur'],
  'Delhi': ['New Delhi', 'Delhi'],
  'Goa': ['Panaji', 'Vasco da Gama', 'Margao'],
  'Gujarat': ['Ahmedabad', 'Surat', 'Vadodara', 'Rajkot'],
  'Haryana': ['Gurugram', 'Faridabad', 'Panipat', 'Hisar'],
  'Himachal Pradesh': ['Shimla', 'Dharamshala', 'Solan'],
  'Jharkhand': ['Ranchi', 'Jamshedpur', 'Dhanbad'],
  'Jammu and Kashmir': ['Srinagar', 'Jammu'],
  'Karnataka': ['Bengaluru', 'Mysuru', 'Mangaluru', 'Hubballi'],
  'Kerala': ['Thiruvananthapuram', 'Kochi', 'Kozhikode', 'Thrissur'],
  'Madhya Pradesh': ['Bhopal', 'Indore', 'Jabalpur', 'Gwalior'],
  'Maharashtra': ['Mumbai', 'Pune', 'Nagpur', 'Nashik', 'Aurangabad'],
  'Manipur': ['Imphal'],
  'Meghalaya': ['Shillong'],
  'Odisha': ['Bhubaneswar', 'Cuttack', 'Rourkela'],
  'Punjab': ['Chandigarh', 'Ludhiana', 'Amritsar', 'Jalandhar'],
  'Rajasthan': ['Jaipur', 'Jodhpur', 'Udaipur', 'Kota', 'Bikaner'],
  'Tamil Nadu': ['Chennai', 'Coimbatore', 'Madurai', 'Salem'],
  'Telangana': ['Hyderabad', 'Warangal', 'Nizamabad'],
  'Uttar Pradesh': [
    'Lucknow',
    'Kanpur',
    'Noida',
    'Prayagraj',
    'Varanasi',
    'Agra',
  ],
  'Uttarakhand': ['Dehradun', 'Haridwar', 'Haldwani'],
  'West Bengal': ['Kolkata', 'Siliguri', 'Durgapur', 'Howrah'],
};

List<String> get indiaStates => indiaCitiesByState.keys.toList(growable: false);

List<String> citiesForState(String state) =>
    indiaCitiesByState[state] ?? const <String>[];
