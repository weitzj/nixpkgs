{
  lib,
  stdenv,
  buildGoModule,
  fetchFromGitHub,
  installShellFiles,
  btrfs-progs,
  testers,
  werf,
}:

buildGoModule rec {
  pname = "werf";
  version = "2.12.1";

  src = fetchFromGitHub {
    owner = "werf";
    repo = "werf";
    rev = "v${version}";
    hash = "sha256-EVFNUOvczsgU0t2hOfl4e5bFH4ByxmRsIk2idI+uquQ=";
  };

  vendorHash = "sha256-eJT3ROX/cAslWMNUdlFU6eQE8o2GlAFKrBaT//Pde1o=";

  proxyVendor = true;

  subPackages = [ "cmd/werf" ];

  nativeBuildInputs = [ installShellFiles ];

  buildInputs =
    lib.optionals stdenv.hostPlatform.isLinux [ btrfs-progs ]
    ++ lib.optionals stdenv.hostPlatform.isGnu [ stdenv.cc.libc.static ];

  CGO_ENABLED = if stdenv.hostPlatform.isLinux then 1 else 0;

  ldflags =
    [
      "-s"
      "-w"
      "-X github.com/werf/werf/v2/pkg/werf.Version=v${version}"
    ]
    ++ lib.optionals (CGO_ENABLED == 1) [
      "-extldflags=-static"
      "-linkmode external"
    ];

  tags =
    [
      "containers_image_openpgp"
      "dfrunmount"
      "dfrunnetwork"
      "dfrunsecurity"
      "dfssh"
    ]
    ++ lib.optionals (CGO_ENABLED == 1) [
      "cni"
      "exclude_graphdriver_devicemapper"
      "netgo"
      "no_devmapper"
      "osusergo"
      "static_build"
    ];

  preCheck =
    ''
      # Test all targets.
      unset subPackages

      # Remove tests that require external services.
      rm -rf \
        integration/suites \
        pkg/true_git/*test.go \
        test/e2e
    ''
    + lib.optionalString (CGO_ENABLED == 0) ''
      # A workaround for osusergo.
      export USER=nixbld
    '';

  postInstall = ''
    installShellCompletion --cmd werf \
      --bash <($out/bin/werf completion --shell=bash) \
      --zsh <($out/bin/werf completion --shell=zsh)
  '';

  passthru.tests.version = testers.testVersion {
    package = werf;
    command = "werf version";
    version = src.rev;
  };

  meta = with lib; {
    description = "GitOps delivery tool";
    mainProgram = "werf";
    longDescription = ''
      The CLI tool gluing Git, Docker, Helm & Kubernetes with any CI system to
      implement CI/CD and Giterminism.
    '';
    homepage = "https://werf.io";
    changelog = "https://github.com/werf/werf/releases/tag/${src.rev}";
    license = licenses.asl20;
    maintainers = with maintainers; [ azahi ];
  };
}
