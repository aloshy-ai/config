let
  aloshy = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMyizay27AAwIXA84BU9bgmb6/YA4cR8WpJgmPr1Ebvz";
  users = [ aloshy ];
  systems = [ ];
in {
  "test-secret-5.age".publicKeys = [ aloshy ];
  # Secrets will be added here
}
