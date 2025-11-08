use proc_macro::TokenStream;
use quote::quote;
use syn::{DeriveInput, parse_macro_input};

/// Signal derive macro generating an impl of the [`Signal`] trait.
///
/// The trait is implemented using the module path and the name of the type.
#[proc_macro_derive(Signal)]
pub fn derive_signal(input: TokenStream) -> TokenStream {
    let input = parse_macro_input!(input as DeriveInput);

    let name = input.ident;

    let expanded = quote! {
        impl Signal for #name{
            fn signal_name() -> & 'static str {
                concat!(module_path!(), "::", stringify!(#name))
            }
        }
    };

    expanded.into()
}

//TODO: Implaement derive for Emitter.
